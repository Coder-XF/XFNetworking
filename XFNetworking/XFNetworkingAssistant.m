//
//  XFNetworkingAssistant.m
//  XFNetworkingDemo
//
//  Created by 许飞 on 2020/6/15.
//  Copyright © 2020 CoderXF. All rights reserved.
//

#import "XFNetworkingAssistant.h"


/**
 Returns a percent-escaped string following RFC 3986 for a query string key or value.
 RFC 3986 states that the following characters are "reserved" characters.
 - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
 - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
 
 In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
 query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
 should be percent-escaped in the query string.
 - parameter string: The string to be percent-escaped.
 - returns: The percent-escaped string.
 */
NSString *xfPercentEscapedStringFromString(NSString *string) {
    static NSString * const kAFCharactersGeneralDelimitersToEncode = @":#[]@"; // does not include "?" or "/" due to RFC 3986 - Section 3.4
    static NSString * const kAFCharactersSubDelimitersToEncode = @"!$&'()*+,;=";
    
    NSMutableCharacterSet * allowedCharacterSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowedCharacterSet removeCharactersInString:[kAFCharactersGeneralDelimitersToEncode stringByAppendingString:kAFCharactersSubDelimitersToEncode]];
    
    // FIXME: https://github.com/AFNetworking/AFNetworking/pull/3028
    // return [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
    
    static NSUInteger const batchSize = 50;
    
    NSUInteger index = 0;
    NSMutableString *escaped = @"".mutableCopy;
    
    while (index < string.length) {
        NSUInteger length = MIN(string.length - index, batchSize);
        NSRange range = NSMakeRange(index, length);
        
        // To avoid breaking up character sequences such as 👴🏻👮🏽
        range = [string rangeOfComposedCharacterSequencesForRange:range];
        
        NSString *substring = [string substringWithRange:range];
        NSString *encoded = [substring stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
        [escaped appendString:encoded];
        
        index += range.length;
    }
    
    return escaped;
}

@implementation XFQueryStringPair

- (instancetype)initWithField:(id)field value:(id)value {
    if (self = [super init]) {
        self.field = field;
        self.value = value;
    }
    return self;
}

- (NSString *)URLEncodedStringValue {
    if (!self.value || [self.value isEqual:[NSNull null]]) {
        return xfPercentEscapedStringFromString([self.field description]);
    } else {
        return [NSString stringWithFormat:@"%@=%@", xfPercentEscapedStringFromString([self.field description]), xfPercentEscapedStringFromString([self.value description])];
    }
}

@end

NSString * XFQueryStringFromParameters(NSDictionary *parameters) {
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (XFQueryStringPair *pair in XFQueryStringPairsFromDictionary(parameters)) {
        [mutablePairs addObject:[pair URLEncodedStringValue]];
    }
    return [mutablePairs componentsJoinedByString:@"&"];
}

NSArray * XFQueryStringPairsFromDictionary(NSDictionary *dictionary) {
    return XFQueryStringPairsFromKeyAndValue(nil, dictionary);
}

NSArray * XFQueryStringPairsFromKeyAndValue(NSString *key, id value) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:YES selector:@selector(compare:)];
    
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        // Sort dictionary keys to ensure consistent ordering in query string, which is important when deserializing potentially ambiguous sequences, such as an array of dictionaries
        for (id nestedKey in [dictionary.allKeys sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
            id nestedValue = dictionary[nestedKey];
            if (nestedValue) {
                [mutableQueryStringComponents addObjectsFromArray:XFQueryStringPairsFromKeyAndValue((key ? [NSString stringWithFormat:@"%@[%@]", key, nestedKey] : nestedKey), nestedValue)];
            }
        }
    } else if ([value isKindOfClass:[NSArray class]]) {
        NSArray *array = value;
        for (id nestedValue in array) {
            [mutableQueryStringComponents addObjectsFromArray:XFQueryStringPairsFromKeyAndValue([NSString stringWithFormat:@"%@[]", key], nestedValue)];
        }
    } else if ([value isKindOfClass:[NSSet class]]) {
        NSSet *set = value;
        for (id obj in [set sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
            [mutableQueryStringComponents addObjectsFromArray:XFQueryStringPairsFromKeyAndValue(key, obj)];
        }
    } else {
        [mutableQueryStringComponents addObject:[[XFQueryStringPair alloc] initWithField:key value:value]];
    }
    
    return mutableQueryStringComponents;
}

@implementation NSDictionary (xfNetworking)

+ (NSString *)xf_paramterTransformToString:(NSDictionary *)parameter {
    if (parameter && [parameter isKindOfClass:[NSDictionary class]]) {
        if (parameter.allKeys.count == 0) {
            return nil;
        }
        NSMutableString *_postString = [NSMutableString string];
        for (NSString *key in parameter.allKeys) {
            [_postString appendString:[NSString stringWithFormat:@"%@=%@&",key,parameter[key]]];
        }
        return [_postString substringToIndex:_postString.length - 1];
    }
    return nil;
}

+ (nullable NSString *)xf_dictionaryToJSONString:(NSDictionary *)dic {
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    if (data) {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

@end

#pragma mark - NSMutableURLRequest分类

@implementation NSMutableURLRequest (xfNetworking)

// 设置URL
+ (NSURLRequestInstanceBlock)xf_requestWithURL {
    return ^NSMutableURLRequest *(NSString *url) {
        return [self xf_requestWithURLString:url];
    };
}

+ (NSMutableURLRequest *)xf_requestWithURLString:(NSString *)string {
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:string]];
}

// 设置timeout
- (NSURLRequestTimeoutBlock)xf_setTimeout {
    return ^NSMutableURLRequest *(NSTimeInterval timeout) {
        self.timeoutInterval = timeout;
        return self;
    };
}

// 设置UA
- (NSURLRequestStringSetBlock)xf_setUA {
    return ^NSMutableURLRequest *(NSString *value) {
        [self setValue:value forHTTPHeaderField:@"User-Agent"];
        return self;
    };
}

// 设置Cache策略
- (NSURLRequestPolicySetBlock)xf_setPolicy {
    return ^NSMutableURLRequest *(NSURLRequestCachePolicy policy) {
        self.cachePolicy = policy;
        return self;
    };
}

// 设置HTTP请求方法
- (NSURLRequestStringSetBlock)xf_setMethod {
    return ^NSMutableURLRequest *(NSString *value) {
        self.HTTPMethod = value;
        return self;
    };
}

// 设置是否处理Cookie
- (NSURLRequestBOOLSetBlock)xf_handleCookie {
    return ^NSMutableURLRequest *(BOOL value) {
        self.HTTPShouldHandleCookies = value;
        return self;
    };
}

// 添加请求头
- (NSURLRequestDictionarySetBlock)xf_addHeaderValues {
    return ^NSMutableURLRequest *(NSDictionary *dic) {
        for (NSString *key in dic.allKeys) {
            [self setValue:dic[key] forHTTPHeaderField:key];
        }
        return self;
    };
}

// 设置请求体
- (NSURLRequestDictionarySetBlock)xf_setHTTPParameter {
    return ^NSMutableURLRequest *(NSDictionary *dic) {
        NSString *httpBodyString = XFQueryStringFromParameters(dic);
        self.HTTPBody = [httpBodyString dataUsingEncoding:NSUTF8StringEncoding];
        return self;
    };
}

// 设置请求体 转化为 JSON 数据
- (NSURLRequestJSONSetBlock)xf_setJSONParameter {
    return ^NSMutableURLRequest *(NSDictionary *dic ,NSError *error) {
        if (dic) {
            self.HTTPBody = [NSJSONSerialization dataWithJSONObject:dic options:0 error:&error];
        }
        return self;
    };
}

@end

#pragma mark - NSError分类

@implementation NSError (xfNetworking)

+ (NSError *)xf_errorWithCode:(NSInteger)code
                     description:(NSString *)description {
    return [NSError errorWithDomain:@"com.xf.networking" code:code userInfo:@{NSLocalizedDescriptionKey:description}];
}

+ (XFNetworkingErrorInstacnceBlock)xf_errorWithInfo {
    return ^NSError *(NSInteger code, NSString *errorDescription) {
        return [NSError xf_errorWithCode:code description:errorDescription];
    };
}

+ (NSError *)xf_netError {
    return [self xf_errorWithCode:3003 description:@"请求失败！"];
}

@end

