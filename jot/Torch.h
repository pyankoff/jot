//
//  Torch.h
//

#import <UIKit/UIKit.h>

#import "Torch/lua.h"
#import "Torch/TH/TH.h"
#import "Torch/luaT.h"
#import "Torch/lualib.h"
#import "Torch/lauxlib.h"

LUA_API int luaopen_libtorch(lua_State *L);
LUA_API int luaopen_libnn(lua_State *L);
LUA_API int luaopen_libnnx(lua_State *L);
LUA_API int luaopen_libimage(lua_State *L);

@interface Torch : NSObject
{
    lua_State *L;
}

- (void)require:(NSString *)file;
- (void)initialize;
- (int) performClassification:(NSMutableArray *) binaryImage rows:(int)rows cols:(int)cols type:(NSString *)type;

@end
