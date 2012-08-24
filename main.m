/*
  pdf2png for doc-view-mode on emacs

*/


#include <Foundation/Foundation.h>

#define BEST_BYTE_ALIGNMENT 16
#define COMPUTE_BEST_BYTES_PER_ROW(bpr)		( ( (bpr) + (BEST_BYTE_ALIGNMENT-1) ) & ~(BEST_BYTE_ALIGNMENT-1) )

// Prototypes;
CGPDFDocumentRef openPDFDocument (const char *filename);
void closePDFDocument (CGPDFDocumentRef document);
CGContextRef createBitmapContextForPNG(CGPDFDocumentRef document, float dpi);
void releaseBitmapContext(CGContextRef context);
CGImageRef createRGBAImageFromQuartzDrawing(CGContextRef context, CGPDFDocumentRef document, int pageNumber, float dpi);
void exportPageToPNG(CGContextRef context, CGPDFDocumentRef document, int pageNumber, int dpi, char *pngPath);

int main(int argc, char *argv[])
{
	CGContextRef context;
	CGPDFDocumentRef document;
	size_t count;
	float dpi;
	char *pngPath;
	size_t firstPage = 1;
	size_t lastPage = 0;

	int i = 1;
	for (; i < argc ; i++) {
		char hyphen = argv[i][0];
		char option = argv[i][1];

		if (hyphen == '-')
		{
			if (option == 'r')
			{
				char cDPI[8];
				int j = 2;
				for (; j < strlen(argv[i]); j++)
				{
					cDPI[j-2] = argv[i][j];
				}
				
				cDPI[j-2] = 0;
				dpi = atof(cDPI);
				NSLog(@"pdf2png : dpi = %f\n", dpi);
			}
			else if (option == 's')
			{
				if (argv[i][2] == 'O')
				{
					pngPath = &argv[i][13]; // hack!
				
					NSLog(@"pdf2png : pngPath = %s\n", pngPath);
				}
			}
			else if (option == 'd')
			{
				if (argv[i][2] == 'F')
				{
					char *page = &argv[i][12];
					firstPage = atoi(page);
				} else if (argv[i][2] == 'L')
				{
					char *page = &argv[i][11];
					lastPage = atoi(page);
				}
				
//				NSLog(@"pdf2png : argv[%d] = %s\n", i, argv[i]);
			}
		}
	}

//	NSLog(@"pdf2pdf : opening %s\n", argv[argc-1]);


	document = openPDFDocument(argv[argc-1]);
    count = CGPDFDocumentGetNumberOfPages (document);// 3
    if (count == 0) {
        NSLog(@"the document needs at least one page!");
        return 1;
    }
	if (lastPage == 0) lastPage = count;

	context = createBitmapContextForPNG(document, dpi);

	NSLog(@"pdf2png : firstpage = %zu, lastpage = %zu\n", firstPage, lastPage);
	
	for (int i = firstPage; i <= lastPage; i++)
	{
		exportPageToPNG(context, document, i, dpi, pngPath);
	}

	releaseBitmapContext(context);
	closePDFDocument(document);
	
	return 0;
}

CGPDFDocumentRef openPDFDocument (const char *filename)
{
    CFStringRef path;
    CFURLRef url;
    CGPDFDocumentRef document;

    path = CFStringCreateWithCString (NULL, filename, kCFStringEncodingUTF8);
    url = CFURLCreateWithFileSystemPath (NULL, path, // 1
										 kCFURLPOSIXPathStyle, 0);
    CFRelease (path);
    document = CGPDFDocumentCreateWithURL (url);// 2
    CFRelease(url);
    return document;
}

void closePDFDocument (CGPDFDocumentRef document)
{
//	CGPDFDocumentRelease(document);
}

static CGColorSpaceRef myGetGenericRGBSpace(void)
{
    // Only create the color space once.
    static CGColorSpaceRef colorSpace = NULL;
    if ( colorSpace == NULL ) {
		colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    }
    return colorSpace;
}

CGContextRef createBitmapContextForPNG(CGPDFDocumentRef document, float dpi)
{
    // For generating RGBA data from drawing. Use a Letter size page as the
    // image dimensions. Typically this size would be the minimum necessary to
    // capture the drawing of interest. We want 8 bits per component and for
    // RGBA data there are 4 components.
//	float dpi = 75;
//    size_t width = 8.5*dpi, height = 11*dpi, bitsPerComponent = 8,
//    numComps = 4;
//	size_t width = 7*dpi, height = 9.19*dpi, bitsPerComponent = 8, numComps = 4;
	CGPDFPageRef page = CGPDFDocumentGetPage (document, 1);// 2
	CGRect rect = CGPDFPageGetBoxRect( page, kCGPDFTrimBox);
	
//	size_t width = 5.8*dpi, height = 11*dpi, bitsPerComponent = 8,
//	numComps = 4;
	size_t width = rect.size.width / 72. * dpi;
	size_t height = rect.size.height / 72. * dpi;
	size_t bitsPerComponent = 8, numComps = 4;
	NSLog(@"pdf2png : width = %zu, height = %zu\n", width, height);
	
    // Compute the minimum number of bytes in a given scanline.
    size_t bytesPerRow = width* bitsPerComponent/8 * numComps;

    // This bitmapInfo value specifies that we want the format where alpha is
    // premultiplied and is the last of the components. We use this to produce
    // RGBA data.
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast;

    // Round to nearest multiple of BEST_BYTE_ALIGNMENT for optimal performance.
    bytesPerRow = COMPUTE_BEST_BYTES_PER_ROW(bytesPerRow);

    // Allocate the data for the bitmap.
    char *data = malloc( bytesPerRow * height );

    // Create the bitmap context. Characterize the bitmap data with the
    // Generic RGB color space.
    CGContextRef bitmapContext = CGBitmapContextCreate(
		data, width, height, bitsPerComponent, bytesPerRow,
	    myGetGenericRGBSpace(), bitmapInfo);


    // Scale the coordinate system so that 72 units are dpi pixels.
    CGContextScaleCTM( bitmapContext, dpi/72 , dpi/72 );

	return bitmapContext;
}

void releaseBitmapContext(CGContextRef context)
{
    // Release the bitmap context object and free the associated raster memory.
	char *data = CGBitmapContextGetData(context);
    CGContextRelease(context);
    free(data);
}

CGImageRef createRGBAImageFromQuartzDrawing(CGContextRef context, CGPDFDocumentRef document, int pageNumber, float dpi)
{
// Perform the requested drawing.
	
	CGPDFPageRef page;
	size_t width = CGBitmapContextGetWidth(context);
	size_t height = CGBitmapContextGetHeight(context);
	
    // Clear the destination bitmap so that it is completely transparent before
    // performing any drawing. This is appropriate for exporting PNG data or
    // other data formats that capture alpha data. If the destination output
    // format doesn't support alpha then a better choice would be to paint
    // to white.
	CGContextSetFillColorWithColor( context, CGColorGetConstantColor(kCGColorWhite));
//    CGContextClearRect( context, CGRectMake(0, 0, width, height) );
	CGContextFillRect( context, CGRectMake(0, 0, width, height) );

	page = CGPDFDocumentGetPage (document, pageNumber);// 2
    CGContextDrawPDFPage (context, page);// 3
	CGPDFPageRelease(page);

    // Create a CGImage object from the drawing performed to the bitmapContext.
    CGImageRef image = CGBitmapContextCreateImage(context);

    // Return the CGImage object this code created from the drawing.
    return image;
}

void exportPageToPNG(CGContextRef context, CGPDFDocumentRef document, int pageNumber, int dpi, char *pngPath)
{
//    float dpi = 75;
    // Create an RGBA image from the Quartz drawing that corresponds to drawingCommand.
    CGImageRef image = createRGBAImageFromQuartzDrawing(context, document, pageNumber, dpi);

    CFTypeRef keys[2], values[2];
    CFDictionaryRef properties = NULL;

    // Create a CGImageDestination object will write PNG data to URL.
    // We specify that this object will hold 1 image.
    CGImageDestinationRef imageDestination;
    CFStringRef path;
    CFURLRef url;

	char pngFile[256];
	sprintf(pngFile, pngPath, pageNumber);
//	NSLog(@"pdf2png : processing %s\n", pngFile);
	
    path = CFStringCreateWithCString (NULL, pngFile, kCFStringEncodingUTF8);
    url = CFURLCreateWithFileSystemPath (NULL, path, // 1
										 kCFURLPOSIXPathStyle, 0);

	imageDestination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);

    // Set the keys to be the x and y resolution properties of the image.
    keys[0] = kCGImagePropertyDPIWidth;
    keys[1] = kCGImagePropertyDPIHeight;

    // Create a CFNumber for the resolution and use it as the
    // x and y resolution.
    values[0] = values[1] = CFNumberCreate(NULL, kCFNumberFloatType, &dpi);

    // Create an properties dictionary with these keys.
    properties = CFDictionaryCreate(NULL,
									(const void **)keys,
									(const void **)values,
									2,
									&kCFTypeDictionaryKeyCallBacks,
									&kCFTypeDictionaryValueCallBacks);

    // Release the CFNumber the code created.
    CFRelease(values[0]);

    // Add the image to the destination, characterizing the image with
    // the properties dictionary.
    CGImageDestinationAddImage(imageDestination, image, properties);

    // Release the CGImage object that createRGBAImageFromQuartzDrawing
    // created.
    CGImageRelease(image);

    // Release the properties dictionary.
    CFRelease(properties);

    // When all the images (only 1 in this example) are added to the destination,
    // finalize the CGImageDestination object.
    CGImageDestinationFinalize(imageDestination);

    // Release the CGImageDestination when finished with it.
    CFRelease(imageDestination);
}
