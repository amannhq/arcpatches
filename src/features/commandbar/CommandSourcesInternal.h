// Private to the command bar's sources (CommandSources.m, CommandRanking.m, CommandHistory.m).
#import "CommandSources.h"
#include <sqlite3.h>

@interface TweakCommandSources () {
    NSArray<TweakItem *> *_commands;
    NSArray<TweakItem *> *_pages;
    NSArray<TweakItem *> *_tabs;
    NSArray<TweakItem *> *_bookmarks;
    NSString *_searchTemplate;
    NSString *_activeURL;
    dispatch_queue_t _queue;
    _Atomic NSUInteger _generation;  // read on the history queue to skip superseded queries
    NSCache<NSString *, id> *_icons;
}
- (NSString *)searchEngineName;
@end

@interface TweakCommandSources (HistoryQueries)
// Read-only, never locks the browser's databases.
- (void)sqlite:(NSString *)file query:(NSString *)sql bind:(NSArray *)args row:(void (^)(sqlite3_stmt *))row;
- (NSArray<TweakItem *> *)historyFor:(NSArray<NSString *> *)words;
@end

// The last-used profile's folder (Local State → profile.last_used), else Default.
NSString *TweakCommandProfileDir(void);
