//
//  xfNetworkingAssistant.h
//  xfNetworkingDemo
//
//  Created by 许飞 on 2020/6/15.
//  Copyright © 2020 Coderxf. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XFQueryStringPair : NSObject

@property (readwrite, nonatomic, strong) id field;
@property (readwrite, nonatomic, strong) id value;

- (instancetype)initWithField:(id)field value:(id)value;
- (NSString *)URLEncodedStringValue;

@end

/**
 Returns a percent-escaped string following RFC 3986 for a query string key or value.
 RFC 3986 states that the following characters are "reserved" characters.
 - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
 - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
 
 In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
 query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
 should be percent-escaped in the query string.
 
 @param string The string to be percent-escaped.
 
 @return The percent-escaped string.
 */
extern NSString *XFPercentEscapedStringFromString(NSString *string);

/**
 A helper method to generate encoded url query parameters for appending to the end of a URL.
 
 @param parameters A dictionary of key/values to be encoded.
 
 @return A url encoded query string
 */
extern NSString *XFQueryStringFromParameters(NSDictionary *parameters);
extern NSArray <XFQueryStringPair *> * XFQueryStringPairsFromDictionary(NSDictionary *dictionary);
extern NSArray <XFQueryStringPair *> * XFQueryStringPairsFromKeyAndValue(NSString *_Nullable key, id value);

#pragma mark - NSDictionary

@interface NSDictionary (XFNetworking)

+ (nullable NSString *)xf_dictionaryToJSONString:(NSDictionary *)dic;

@end

#pragma mark - NSMutableURLRequest

typedef NSMutableURLRequest *_Nonnull(^NSURLRequestInstanceBlock)(NSString *url);
typedef NSMutableURLRequest *_Nonnull(^NSURLRequestPolicySetBlock)(NSURLRequestCachePolicy policy);
typedef NSMutableURLRequest *_Nonnull(^NSURLRequestTimeoutBlock)(NSTimeInterval timeout);
typedef NSMutableURLRequest *_Nonnull(^NSURLRequestStringSetBlock)(NSString *value);
typedef NSMutableURLRequest *_Nonnull(^NSURLRequestBOOLSetBlock)(BOOL value);
typedef NSMutableURLRequest *_Nonnull(^NSURLRequestDictionarySetBlock)(NSDictionary *dic);
typedef NSMutableURLRequest *_Nonnull(^NSURLRequestJSONSetBlock)(NSDictionary *dic, NSError *_Nullable error);
typedef NSString *_Nonnull(^XFNetworkingPostHTTPParameterBlock)(NSDictionary *parameter);

@interface NSMutableURLRequest (xfNetworking)

@property (nonatomic, readonly, class) NSURLRequestInstanceBlock     xf_requestWithURL;
@property (nonatomic, copy, readonly) NSURLRequestStringSetBlock     xf_setUA;
@property (nonatomic, copy, readonly) NSURLRequestPolicySetBlock     xf_setPolicy;
@property (nonatomic, copy, readonly) NSURLRequestTimeoutBlock       xf_setTimeout;
@property (nonatomic, copy, readonly) NSURLRequestStringSetBlock     xf_setMethod;
@property (nonatomic, copy, readonly)NSURLRequestBOOLSetBlock       xf_handleCookie;
@property (nonatomic, copy, readonly) NSURLRequestDictionarySetBlock xf_addHeaderValues;
@property (nonatomic, copy, readonly) NSURLRequestDictionarySetBlock xf_setHTTPParameter;
@property (nonatomic, copy, readonly) NSURLRequestJSONSetBlock       xf_setJSONParameter;

+ (NSMutableURLRequest *)xf_requestWithURLString:(NSString *)string;

@end

#pragma mark - NSError

typedef NSError *_Nonnull(^XFNetworkingErrorInstacnceBlock)(NSInteger code ,NSString *errorDescription);

@interface NSError (XFNetworking)

@property (nonatomic, readonly ,class) XFNetworkingErrorInstacnceBlock xf_errorWithInfo;

+ (NSError *)xf_errorWithCode:(NSInteger)code description:(NSString *)description;
+ (NSError *)xf_netError;

@end

NS_ASSUME_NONNULL_END

