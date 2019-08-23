#import "RNOpenCvLibrary.h"
#import <React/RCTLog.h>

@implementation RNOpenCvLibrary

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(concatenateHorizontally:(NSArray *)imagesAsBase64 callback:(RCTResponseSenderBlock)callback) {
  UIImage* image1 = [self decodeBase64ToImage:imagesAsBase64[0]];
  UIImage* image2 = [self decodeBase64ToImage:imagesAsBase64[1]];

  cv::Mat matImage1 = [self cvMatFromUIImage:image1];
  cv::Mat matImage2 = [self cvMatFromUIImage:image2];
  cv::Mat dst;

  cv::hconcat(matImage1, matImage2, dst);
  
  UIImage* dstUI = [self UIImageFromCVMat:dst];
  
  NSString* dstBase64 = [self encodeToBase64String:dstUI];
  
  id object = { dstBase64 };
  NSArray *array = [NSArray arrayWithObject:object];
  
  callback(@[[NSNull null], array]);
}

RCT_EXPORT_METHOD(concatenateVertically:(NSArray *)imagesAsBase64 callback:(RCTResponseSenderBlock)callback) {
  UIImage* image1 = [self decodeBase64ToImage:imagesAsBase64[0]];
  UIImage* image2 = [self decodeBase64ToImage:imagesAsBase64[1]];
  
  cv::Mat matImage1 = [self cvMatFromUIImage:image1];
  cv::Mat matImage2 = [self cvMatFromUIImage:image2];
  cv::Mat dst;
  
  cv::vconcat(matImage1, matImage2, dst);
  
  UIImage* dstUI = [self UIImageFromCVMat:dst];
  
  NSString* dstBase64 = [self encodeToBase64String:dstUI];
  
  id object = { dstBase64 };
  NSArray *array = [NSArray arrayWithObject:object];
  
  callback(@[[NSNull null], array]);
}

RCT_EXPORT_METHOD(changeImageContrast:(NSString *)imageAsBase64 alpha:(double)alpha callback:(RCTResponseSenderBlock)callback) {
  UIImage* image = [self decodeBase64ToImage:imageAsBase64];
  
  cv::Mat matImage = [self cvMatFromUIImage:image];

  cv::Mat new_matImage = cv::Mat::zeros(matImage.size(), matImage.type());

  for (int y = 0; y < matImage.rows; y++ ) {
    for (int x = 0; x < matImage.cols; x++ ) {
      for( int c = 0; c < matImage.channels(); c++ ) {
        new_matImage.at<cv::Vec3b>(y,x)[c] = cv::saturate_cast<uchar>( alpha*matImage.at<cv::Vec3b>(y,x)[c] );
      }
    }
  }

  UIImage* new_imageUI = [self UIImageFromCVMat:new_matImage];
  
  NSString* dstBase64 = [self encodeToBase64String:new_imageUI];
  
  id object = { dstBase64 };
  NSArray *array = [NSArray arrayWithObject:object];
  
  callback(@[[NSNull null], array]);
}

- (UIImage *)UIImageFromCVMat:(cv::Mat)cvMat {
  NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
  
  CGColorSpaceRef colorSpace;
  CGBitmapInfo bitmapInfo;
  
  if (cvMat.elemSize() == 1) {
    colorSpace = CGColorSpaceCreateDeviceGray();
    bitmapInfo = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
  } else {
    colorSpace = CGColorSpaceCreateDeviceRGB();
    bitmapInfo = kCGBitmapByteOrder32Little | (
                                               cvMat.elemSize() == 3? kCGImageAlphaNone : kCGImageAlphaNoneSkipFirst
                                               );
  }
  
  CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
  
  // Creating CGImage from cv::Mat
  CGImageRef imageRef = CGImageCreate(
                                      cvMat.cols,                 //width
                                      cvMat.rows,                 //height
                                      8,                          //bits per component
                                      8 * cvMat.elemSize(),       //bits per pixel
                                      cvMat.step[0],              //bytesPerRow
                                      colorSpace,                 //colorspace
                                      bitmapInfo,                 // bitmap info
                                      provider,                   //CGDataProviderRef
                                      NULL,                       //decode
                                      false,                      //should interpolate
                                      kCGRenderingIntentDefault   //intent
                                      );
  
  // Getting UIImage from CGImage
  UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
  CGImageRelease(imageRef);
  CGDataProviderRelease(provider);
  CGColorSpaceRelease(colorSpace);
  
  return finalImage;
}

- (UIImage *)decodeBase64ToImage:(NSString *)strEncodeData {
  NSData *data = [[NSData alloc]initWithBase64EncodedString:strEncodeData options:NSDataBase64DecodingIgnoreUnknownCharacters];
  return [UIImage imageWithData:data];
}

- (cv::Mat)cvMatFromUIImage:(UIImage *)image {
  CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
  CGFloat cols = image.size.width;
  CGFloat rows = image.size.height;
  
  if  (image.imageOrientation == UIImageOrientationLeft
       || image.imageOrientation == UIImageOrientationRight) {
    cols = image.size.height;
    rows = image.size.width;
  }
  
  cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
  
  CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                  cols,                       // Width of bitmap
                                                  rows,                       // Height of bitmap
                                                  8,                          // Bits per component
                                                  cvMat.step[0],              // Bytes per row
                                                  colorSpace,                 // Colorspace
                                                  kCGImageAlphaNoneSkipLast |
                                                  kCGBitmapByteOrderDefault); // Bitmap info flags
  
  CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
  CGContextRelease(contextRef);
  CGColorSpaceRelease(colorSpace);
  
  //--swap channels -- //
  std::vector<cv::Mat> ch;
  cv::split(cvMat,ch);
  std::swap(ch[0],ch[2]);
  cv::merge(ch,cvMat);
  
  return cvMat;
}

- (NSString *)encodeToBase64String:(UIImage *)image {
  return [UIImagePNGRepresentation(image) base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
}

@end
