// ImGuiDrawView.mm
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ImGui
#import "Esp/CaptainHook.h"
#import "Esp/ImGuiDrawView.h"
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_impl_metal.h"
#import "IMGUI/zzz.h"

// 你的 Patch/Hook 定義
#import "5Toubun/NakanoYotsuba.h"
#import "5Toubun/dobby.h"
#import "5Toubun/il2cpp.h"

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale [UIScreen mainScreen].scale

// ===== 全域狀態變數（替代 Mods struct）=====
static bool g_ShowMenu = false;
static bool g_AttackEnabled = false;
static int g_AttackValue = 9999;
static bool g_InfiniteGems = false;
static float g_SpeedMultiplier = 1.0f;
static bool g_ShowLogs = false;

// ===== 原始函數指標 =====
int (*old_get_attack)(void *instance) = nullptr;
// int (*old_get_health)(void *instance) = nullptr;
// bool (*old_spend_gems)(void *instance, int amount) = nullptr;

// ===== Hook 實作 =====
int new_get_attack(void *instance) {
    if (g_AttackEnabled) {
        return g_AttackValue;
    }
    return old_get_attack ? old_get_attack(instance) : 0;
}

/*
// 範例：無限寶石 Hook
bool new_spend_gems(void *instance, int amount) {
    if (g_InfiniteGems) return true; // 假裝扣款成功
    return old_spend_gems ? old_spend_gems(instance, amount) : false;
}
*/

// ===== 初始化 Hook =====
void initial_setup() {
    // 1. IL2CPP 附著（Unity 遊戲必須）
    Il2CppAttach();
    
    // 2. 手動 Hook 你的 Offset（不依賴 auto-update）
    // getRealOffset 會自動處理 ASLR slide
    void *targetAddr = (void *)getRealOffset(ENCRYPTOFFSET(OFFSET_GET_ATTACK));
    
    if (targetAddr) {
        DobbyHook(targetAddr, (void *)new_get_attack, (void **)&old_get_attack);
        // Console log 會在選單開啟後顯示
    }
    
    // 3. 如果有其他 Hook，在這裡加
    // DobbyHook((void *)getRealOffset(ENCRYPTOFFSET(OFFSET_SPEND_GEMS)), (void *)new_spend_gems, (void **)&old_spend_gems);
}

@interface ImGuiDrawView () <MTKViewDelegate>
@property (nonatomic, strong) id <MTLDevice> device;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;
@end

@implementation ImGuiDrawView

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _device = MTLCreateSystemDefaultDevice();
        _commandQueue = [_device newCommandQueue];
        if (!_device) abort();
        
        IMGUI_CHECKVERSION();
        ImGui::CreateContext();
        ImGuiIO& io = ImGui::GetIO(); (void)io;
        ImGui::StyleColorsDark();
        
        // 載入字體（內建 zzz.h 壓縮字體）
        ImFont* font = io.Fonts->AddFontFromMemoryCompressedTTF(
            (void*)zzz_compressed_data, zzz_compressed_size, 18.0f, NULL, io.Fonts->GetGlyphRangesChineseFull()
        );
        io.FontDefault = font;
        
        ImGui_ImplMetal_Init(_device);
    }
    return self;
}

+ (void)showChange:(BOOL)open {
    g_ShowMenu = open;
}

- (MTKView *)mtkView {
    return (MTKView *)self.view;
}

- (void)loadView {
    CGFloat w = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.width;
    CGFloat h = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.height;
    self.view = [[MTKView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mtkView.device = self.device;
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    self.mtkView.clipsToBounds = YES;
}

#pragma mark - Touch Handling
- (void)updateIOWithTouchEvent:(UIEvent *)event {
    UITouch *anyTouch = event.allTouches.anyObject;
    CGPoint touchLocation = [anyTouch locationInView:self.view];
    ImGuiIO &io = ImGui::GetIO();
    io.MousePos = ImVec2(touchLocation.x, touchLocation.y);
    
    BOOL hasActiveTouch = NO;
    for (UITouch *touch in event.allTouches) {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled) {
            hasActiveTouch = YES;
            break;
        }
    }
    io.MouseDown[0] = hasActiveTouch;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouchEvent:event]; }

#pragma mark - MTKViewDelegate
- (void)drawInMTKView:(MTKView*)view {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(view.bounds.size.width, view.bounds.size.height);
    CGFloat framebufferScale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
    io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);
    io.DeltaTime = 1.0f / (view.preferredFramesPerSecond ?: 60);
    
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    
    // 互動控制
    [self.view setUserInteractionEnabled:g_ShowMenu];
    
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor) {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder pushDebugGroup:@"BiWuDaHui ImGui"];
        
        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui::NewFrame();
        
        // 字體縮放
        ImFont* font = ImGui::GetFont();
        if (font) font->Scale = 18.0f / font->FontSize;
        
        // 視窗位置置中
        ImGui::SetNextWindowPos(ImVec2((view.bounds.size.width - 400) * 0.5f, (view.bounds.size.height - 300) * 0.5f), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(400, 300), ImGuiCond_FirstUseEver);
        
        if (g_ShowMenu) {
            ImGui::Begin("BiWuDaHui Mod Menu", &g_ShowMenu, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize);
            
            ImGui::Text("跨季儲能型「光-氫-熱」三聯供系統");
            ImGui::Separator();
            ImGui::Text("手勢：三指雙擊開啟/關閉選單");
            ImGui::Separator();
            
            // ===== 功能區 =====
            if (ImGui::CollapsingHeader("戰鬥修改", ImGuiTreeNodeFlags_DefaultOpen)) {
                ImGui::Checkbox("自訂攻擊力", &g_AttackEnabled);
                if (g_AttackEnabled) {
                    ImGui::Indent();
                    ImGui::SliderInt("攻擊力數值", &g_AttackValue, 1, 999999);
                    ImGui::Text("Offset: %s", OFFSET_GET_ATTACK);
                    ImGui::Unindent();
                }
                
                ImGui::Checkbox("無限寶石 (阻止扣除)", &g_InfiniteGems);
                ImGui::SliderFloat("移動速度倍率", &g_SpeedMultiplier, 0.5f, 5.0f);
            }
            
            if (ImGui::CollapsingHeader("系統")) {
                ImGui::Checkbox("顯示除錯日誌", &g_ShowLogs);
                if (ImGui::Button("重新載入 Hook")) {
                    initial_setup();
                }
                ImGui::SameLine();
                ImGui::Text("(遊戲更新後使用)");
            }
            
            ImGui::Separator();
            ImGui::Text("FPS: %.1f (%.3f ms/frame)", io.Framerate, 1000.0f / io.Framerate);
            ImGui::Text("Hook 狀態: %s", old_get_attack ? "已載入" : "未載入");
            
            ImGui::End();
            
            // 第一次開啟選單時初始化 Hook
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                initial_setup();
            });
        }
        
        ImGui::Render();
        ImDrawData* draw_data = ImGui::GetDrawData();
        ImGui_ImplMetal_RenderDrawData(draw_data, commandBuffer, renderEncoder);
        
        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }
    [commandBuffer commit];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}

@end
