// SDL_vulkan.h

SDL_Vulkan_LoadLibrary:: (path: *u8) -> u32 #foreign SDL2;

SDL_Vulkan_GetVkGetInstanceProcAddr :: () #foreign SDL2;

SDL_Vulkan_UnloadLibrary :: () -> bool #foreign SDL2;

SDL_Vulkan_GetInstanceExtensions :: (window: *SDL_Window, pCount: *u32, pNames: **u8) -> bool #foreign SDL2;

SDL_Vulkan_CreateSurface :: (window: *SDL_Window, instance: VkInstance, surface: *VkSurfaceKHR) -> bool #foreign SDL2;

SDL_Vulkan_GetDrawableSize :: (window: *SDL_Window, w: *u32, h: *u32) #foreign SDL2;

#import "Vulkan";