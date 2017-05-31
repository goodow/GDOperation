//
// Created by Larry Tin on 2016/12/10.
//

#import <Foundation/Foundation.h>
#import "GDOPBDelta+GDOperation.h"
#import "GDOPBAttribute+FluentInterface.h"

@class GDOPBDelta;
@protocol GDOEditor;

@interface GDORichText : NSObject

- (instancetype)initWithLabel:(UILabel *)label;
- (instancetype)initWithTextView:(UITextView *)textView;
- (instancetype)initWithEditor:(id<GDOEditor>)editor;

#pragma mark - Content

/**
 * Applies Delta to editor contents
 * @return a Delta representing the change. These Deltas will be the same if the Delta passed in had no invalid operations.
 */
- (GDOPBDelta *(^)(GDOPBDelta *delta))updateContents;
/**
 * @return Retrieves contents of the editor, with formatting data, represented by a Delta object.
 */
- (GDOPBDelta *(^)(NSRange range))getContents;
/**
 * Overwrites editor with given contents. Contents should end with a newline '\n'.
 * @return a Delta representing the change. This will be the same as the Delta passed in, if given Delta had no invalid operations.
 */
- (GDOPBDelta *(^)(GDOPBDelta *delta))setContents;
/**
 * @return Retrieves the string contents of the editor. Non-string content are omitted, so the returned string’s length
 * may be shorter than the editor’s as returned by getLength. Note even when Delta is empty, there is still a blank
 * line in the editor, so in these cases getText will return ‘\n’.
 */
- (NSString *(^)(NSRange range))getText;
/**
 * Sets contents of editor with given text. Note documents must end with a newline so one will be added for you if omitted.
 * @return a Delta representing the change.
 */
- (GDOPBDelta *(^)(NSString *text))setText;
/**
 * Deletes text from the editor
 * @return a Delta representing the change.
 */
- (GDOPBDelta *(^)(NSRange range))deleteText;
/**
 * Inserts text into the editor, optionally with a specified format or multiple formats.
 * @return a Delta representing the change.
 */
- (GDOPBDelta *(^)(unsigned long long index, NSString *text, GDOPBAttribute *attributes))insertText;
/**
 * @return Retrieves the length of the editor contents. Note even when Quill is empty, there is still a blank line represented by ‘\n’, so getLength will return 1.
 */
- (unsigned long long(^)())getLength;

#pragma mark - Formatting

/**
 * @return Retrieves common formatting of the text in the given range. For a format to be reported, all text within the
 * range must have a truthy value. If there are different truthy values, an array with all truthy values will be
 * reported.
 */
- (GDOPBAttribute *(^)(NSRange range))getFormat;
/**
 * Formats text in the editor. For line level formats, such as text alignment, target the newline character or use the
 * formatLine helper.
 * @return a Delta representing the change.
 */
- (GDOPBDelta *(^)(NSRange range, GDOPBAttribute *attributes))formatText;
/**
 * Formats all lines in given range. Has no effect when called with inline formats.
 * @return a Delta representing the change
 */
- (GDOPBDelta *(^)(NSRange range, GDOPBAttribute *attributes))formatLine;
/**
 * Removes all formatting and embeds within given range. Line formatting will be removed if any part of the line is
 * included in the range. The user’s selection may not be preserved.
 * @return a Delta representing the change
 */
- (GDOPBDelta *(^)(NSRange range))removeFormat;

@end
