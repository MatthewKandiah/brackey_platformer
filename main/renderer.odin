package main

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:math/linalg/glsl"
import "core:os"
import "vendor:glfw"
import vk "vendor:vulkan"

APP_NAME :: "Brackey Platformer"
REQUIRED_LAYER_NAMES := []cstring{"VK_LAYER_KHRONOS_validation"} if ODIN_DEBUG else nil
REQUIRED_EXTENSION_NAMES := []cstring{vk.KHR_SWAPCHAIN_EXTENSION_NAME}
MAX_FRAMES_IN_FLIGHT :: 2
WINDOW_WIDTH_INITIAL :: 800
WINDOW_HEIGHT_INITIAL :: 600

Vertex :: struct {
	pos: glsl.vec2,
}

vertex_input_binding_description := vk.VertexInputBindingDescription {
	binding   = 0,
	stride    = size_of(Vertex),
	inputRate = .VERTEX,
}

vertex_input_attribute_description := vk.VertexInputAttributeDescription {
  binding = 0, location = 0, format = .R32G32_SFLOAT, offset = cast(u32)offset_of(Vertex, pos)
}

Renderer :: struct {
	command_pool:           vk.CommandPool,
	device:                 vk.Device,
	graphics_pipeline:      vk.Pipeline,
	index_buffer:           vk.Buffer,
	index_buffer_mapped:    rawptr,
	index_buffer_memory:    vk.DeviceMemory,
	physical_device:        vk.PhysicalDevice,
	pipeline_layout:        vk.PipelineLayout,
	queue:                  vk.Queue,
	queue_family_index:     u32,
	render_pass:            vk.RenderPass,
	surface:                vk.SurfaceKHR,
	surface_extent:       vk.Extent2D,
	surface_format:         vk.SurfaceFormatKHR,
	surface_present_mode:   vk.PresentModeKHR,
	swapchain:              vk.SwapchainKHR,
	swapchain_framebuffers: []vk.Framebuffer,
	swapchain_image_views:  []vk.ImageView,
	swapchain_images:       []vk.Image,
	vertex_buffer:          vk.Buffer,
	vertex_buffer_mapped:   rawptr,
	vertex_buffer_memory:   vk.DeviceMemory,
	window:                 glfw.WindowHandle,
  command_buffers:        [MAX_FRAMES_IN_FLIGHT]vk.CommandBuffer,
  frame_index: u32,
  swapchain_image_index: u32,
  sync_fences_in_flight: [MAX_FRAMES_IN_FLIGHT]vk.Fence,
  sync_semaphores_image_available: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
  sync_semaphores_render_finished: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
}

draw_frame :: proc(renderer: ^Renderer) {
  vk.WaitForFences(renderer.device, 1, &renderer.sync_fences_in_flight[renderer.frame_index], true, max(u64))
  acquire_next_image_res := vk.AcquireNextImageKHR(
    renderer.device,
    renderer.swapchain,
    max(u64),
    renderer.sync_semaphores_image_available[renderer.frame_index],
    0,
    &renderer.swapchain_image_index,
  )
  if acquire_next_image_res == .ERROR_OUT_OF_DATE_KHR {
    recreate_swapchain(renderer)
    return
  }
  vk.ResetFences(renderer.device, 1, &renderer.sync_fences_in_flight[renderer.frame_index])
  vk.ResetCommandBuffer(renderer.command_buffers[renderer.frame_index], {})
  command_buffer_begin_info := vk.CommandBufferBeginInfo {
    sType = .COMMAND_BUFFER_BEGIN_INFO,
  }
  if vk.BeginCommandBuffer(renderer.command_buffers[renderer.frame_index], &command_buffer_begin_info) != .SUCCESS {
    panic("failed to begin recording command buffer")
  }
  clear_value := vk.ClearValue {
    color = {float32 = {0,0,0,1}},
  }
  render_pass_begin_info := vk.RenderPassBeginInfo {
    sType = .RENDER_PASS_BEGIN_INFO,
    renderPass = renderer.render_pass,
    framebuffer = renderer.swapchain_framebuffers[renderer.swapchain_image_index],
    renderArea = vk.Rect2D{offset = {0,0}, extent = renderer.surface_extent},
    clearValueCount = 1,
    pClearValues = &clear_value,
  }
  vk.CmdBeginRenderPass(renderer.command_buffers[renderer.frame_index], &render_pass_begin_info, .INLINE)
  vk.CmdBindPipeline(renderer.command_buffers[renderer.frame_index], .GRAPHICS, renderer.graphics_pipeline)
  vertex_buffers := []vk.Buffer{renderer.vertex_buffer}
  offsets := []vk.DeviceSize{0}
  vk.CmdBindVertexBuffers(
    renderer.command_buffers[renderer.frame_index],
    0,
    1,
    raw_data(vertex_buffers),
    raw_data(offsets),
  )
  vk.CmdBindIndexBuffer(
    renderer.command_buffers[renderer.frame_index],
    renderer.index_buffer,
    0,
    .UINT32,
  )
  viewport := vk.Viewport {
    x = 0,
    y = 0,
    width = cast(f32)renderer.surface_extent.width,
    height = cast(f32)renderer.surface_extent.height,
    minDepth = 0,
    maxDepth = 1,
  }
  vk.CmdSetViewport(renderer.command_buffers[renderer.frame_index], 0,1, &viewport)
  scissor := vk.Rect2D {
    offset = {0,0},
    extent = renderer.surface_extent,
  }
  vk.CmdSetScissor(renderer.command_buffers[renderer.frame_index], 0,1, &scissor)
  vk.CmdDrawIndexed(renderer.command_buffers[renderer.frame_index], cast(u32)len(indices), 1,0,0,0)
  vk.CmdEndRenderPass(renderer.command_buffers[renderer.frame_index])
  if vk.EndCommandBuffer(renderer.command_buffers[renderer.frame_index]) != .SUCCESS {
    panic("failed to end command buffer")
  }
  wait_stages := []vk.PipelineStageFlags{{.COLOR_ATTACHMENT_OUTPUT}}
  submit_info := vk.SubmitInfo {
    sType = .SUBMIT_INFO,
    waitSemaphoreCount = 1,
    pWaitSemaphores = &renderer.sync_semaphores_image_available[renderer.frame_index],
    pWaitDstStageMask = raw_data(wait_stages),
    commandBufferCount = 1,
    pCommandBuffers = &renderer.command_buffers[renderer.frame_index],
    signalSemaphoreCount = 1,
    pSignalSemaphores = &renderer.sync_semaphores_render_finished[renderer.frame_index],
  }
  if vk.QueueSubmit(
    renderer.queue,
    1,
    &submit_info,
    renderer.sync_fences_in_flight[renderer.frame_index],
  ) != .SUCCESS {
    panic("failed to submit draw commands to graphics queue")
  }
  present_info := vk.PresentInfoKHR {
    sType = .PRESENT_INFO_KHR,
    waitSemaphoreCount = 1,
    pWaitSemaphores = &renderer.sync_semaphores_render_finished[renderer.frame_index],
    swapchainCount = 1,
    pSwapchains = &renderer.swapchain,
    pImageIndices = &renderer.swapchain_image_index,
  }
  present_res := vk.QueuePresentKHR(renderer.queue, &present_info)
  if present_res == .ERROR_OUT_OF_DATE_KHR ||
     present_res == .SUBOPTIMAL_KHR ||
     gc.framebuffer_resized {
    gc.framebuffer_resized = false
    recreate_swapchain(renderer)
  } else if present_res != .SUCCESS {
    panic("failed to present swapchain image")
  }
  renderer.frame_index += 1
  renderer.frame_index %= MAX_FRAMES_IN_FLIGHT
}

init_renderer :: proc() -> (renderer: Renderer) {
	{ 	// set up window  
		if !glfw.Init() {
			panic("glfwInit failed")
		}

		error_callback :: proc "c" (error: i32, description: cstring) {
			context = runtime.default_context()
			fmt.eprintln("ERROR:", error, description)
			panic("glfw error")
		}
		glfw.SetErrorCallback(error_callback)

		glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
		glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE)
		renderer.window = glfw.CreateWindow(
			WINDOW_WIDTH_INITIAL,
			WINDOW_HEIGHT_INITIAL,
			APP_NAME,
			nil,
			nil,
		)
		if renderer.window == nil {panic("glfw create window failed")}

    glfw.SetWindowUserPointer(renderer.window, &gc)
		framebuffer_resize_callback :: proc "c" (
			window: glfw.WindowHandle,
			width: i32,
			height: i32,
		) {
			user_ptr := cast(^GlobalContext)glfw.GetWindowUserPointer(window)
			user_ptr.framebuffer_resized = true
		}
		glfw.SetFramebufferSizeCallback(renderer.window, framebuffer_resize_callback)
	}

	{ 	// initialise Vulkan instance
		get_proc_address :: proc(p: rawptr, name: cstring) {
			global_context := cast(^GlobalContext)context.user_ptr
			(cast(^rawptr)p)^ = glfw.GetInstanceProcAddress(global_context.vk_instance, name)
		}
		vk.load_proc_addresses(get_proc_address)
		application_info := vk.ApplicationInfo {
			sType              = .APPLICATION_INFO,
			pApplicationName   = APP_NAME,
			applicationVersion = vk.MAKE_VERSION(1, 0, 0),
			pEngineName        = "None",
			engineVersion      = vk.MAKE_VERSION(1, 0, 0),
			apiVersion         = vk.API_VERSION_1_3,
		}
		glfw_required_instance_extensions := glfw.GetRequiredInstanceExtensions()
		instance_create_info := vk.InstanceCreateInfo {
			sType                   = .INSTANCE_CREATE_INFO,
			pApplicationInfo        = &application_info,
			enabledExtensionCount   = cast(u32)len(glfw_required_instance_extensions),
			ppEnabledExtensionNames = raw_data(glfw_required_instance_extensions),
			enabledLayerCount       = cast(u32)len(REQUIRED_LAYER_NAMES),
			ppEnabledLayerNames     = raw_data(REQUIRED_LAYER_NAMES),
		}
		if vk.CreateInstance(&instance_create_info, nil, &gc.vk_instance) != .SUCCESS {
			panic("create instance failed")
		}
	}

	if glfw.CreateWindowSurface(gc.vk_instance, renderer.window, nil, &renderer.surface) !=
	   .SUCCESS {
		panic("create window surface failed")
	}

	{ 	// get physical device
		check_extension_support :: proc(device: vk.PhysicalDevice) -> bool {
			count: u32
			vk.EnumerateDeviceExtensionProperties(device, nil, &count, nil)
			extension_properties := make([]vk.ExtensionProperties, count)
			defer delete(extension_properties)
			vk.EnumerateDeviceExtensionProperties(
				device,
				nil,
				&count,
				raw_data(extension_properties),
			)
			for required_extension_name in REQUIRED_EXTENSION_NAMES {
				found := false
				for available_extension_properties in extension_properties {
					available_extension_name := available_extension_properties.extensionName
					if cast(cstring)&available_extension_name[0] == required_extension_name {
						found = true
					}
				}
				if !found {
					return false
				}
			}
			return true
		}

		check_feature_support :: proc(device: vk.PhysicalDevice) -> b32 {
			supported_features: vk.PhysicalDeviceFeatures
			vk.GetPhysicalDeviceFeatures(device, &supported_features)
			return supported_features.samplerAnisotropy
		}

		count: u32
		vk.EnumeratePhysicalDevices(gc.vk_instance, &count, nil)
		if count == 0 {
			panic("failed to find a Vulkan compatible device")
		}
		physical_devices := make([]vk.PhysicalDevice, count)
		defer delete(physical_devices)
		if vk.EnumeratePhysicalDevices(gc.vk_instance, &count, raw_data(physical_devices)) !=
		   .SUCCESS {
			panic("enumerate physical devices failed")
		}
		for physical_device in physical_devices {
			if !(check_extension_support(physical_device) &&
				   check_feature_support(physical_device)) {
				continue
			}
			properties: vk.PhysicalDeviceProperties
			vk.GetPhysicalDeviceProperties(physical_device, &properties)
			if properties.deviceType == .DISCRETE_GPU {
				renderer.physical_device = physical_device
				break
			} else if properties.deviceType == .INTEGRATED_GPU {
				renderer.physical_device = physical_device
			}
		}
		if renderer.physical_device == nil {
			panic("failed to get physical device")
		}
	}

	{ 	// create logical device and queue
		get_queue_family_properties :: proc(
			physical_device: vk.PhysicalDevice,
		) -> []vk.QueueFamilyProperties {
			count: u32
			vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &count, nil)
			queue_family_properties := make([]vk.QueueFamilyProperties, count)
			defer delete(queue_family_properties)
			vk.GetPhysicalDeviceQueueFamilyProperties(
				physical_device,
				&count,
				raw_data(queue_family_properties),
			)
			return queue_family_properties
		}
		queue_families_properties := get_queue_family_properties(renderer.physical_device)
		// using the first queue family that supports all required operations, just for simplicity
		for queue_family_properties, queue_family_index in queue_families_properties {
			if .GRAPHICS not_in queue_family_properties.queueFlags {continue}
			present_supported: b32
			if vk.GetPhysicalDeviceSurfaceSupportKHR(
				   renderer.physical_device,
				   cast(u32)queue_family_index,
				   renderer.surface,
				   &present_supported,
			   ) !=
			   .SUCCESS {
				panic("failed to check surface presentation support")
			}
			if !present_supported {continue}
			renderer.queue_family_index = cast(u32)queue_family_index
			break
		}
		queue_priority: f32 = 1
		device_queue_create_info := vk.DeviceQueueCreateInfo {
			sType            = .DEVICE_QUEUE_CREATE_INFO,
			queueFamilyIndex = renderer.queue_family_index,
			queueCount       = 1,
			pQueuePriorities = &queue_priority,
		}
		required_device_features := vk.PhysicalDeviceFeatures {
			samplerAnisotropy = true,
		}
		create_info := vk.DeviceCreateInfo {
			sType                   = .DEVICE_CREATE_INFO,
			pQueueCreateInfos       = &device_queue_create_info,
			queueCreateInfoCount    = 1,
			ppEnabledExtensionNames = raw_data(REQUIRED_EXTENSION_NAMES),
			enabledExtensionCount   = cast(u32)len(REQUIRED_EXTENSION_NAMES),
			pEnabledFeatures        = &required_device_features,
		}
		if vk.CreateDevice(renderer.physical_device, &create_info, nil, &renderer.device) !=
		   .SUCCESS {
			panic("failed to create logical device")
		}
		vk.GetDeviceQueue(renderer.device, renderer.queue_family_index, 0, &renderer.queue)
	}

	{ 	// select physical device surface format and present mode
		get_physical_device_surface_formats :: proc(
			physical_device: vk.PhysicalDevice,
			surface: vk.SurfaceKHR,
		) -> []vk.SurfaceFormatKHR {
			count: u32
			vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &count, nil)
			if count == 0 {
				panic("found no physical device surface formats")
			}
			supported_surface_formats := make([]vk.SurfaceFormatKHR, count)
			if res := vk.GetPhysicalDeviceSurfaceFormatsKHR(
				physical_device,
				surface,
				&count,
				raw_data(supported_surface_formats),
			); res != vk.Result.SUCCESS {
				panic("get physical device surface formats failed")
			}
			return supported_surface_formats
		}

		get_physical_device_surface_present_modes :: proc(
			physical_device: vk.PhysicalDevice,
			surface: vk.SurfaceKHR,
		) -> []vk.PresentModeKHR {
			count: u32
			vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &count, nil)
			if count == 0 {
				panic("found no physical device surface present modes")
			}
			supported_surface_present_modes := make([]vk.PresentModeKHR, count)
			if res := vk.GetPhysicalDeviceSurfacePresentModesKHR(
				physical_device,
				surface,
				&count,
				raw_data(supported_surface_present_modes),
			); res != vk.Result.SUCCESS {
				panic("get physical device surface present modes failed")
			}
			return supported_surface_present_modes
		}

		supported_formats := get_physical_device_surface_formats(
			renderer.physical_device,
			renderer.surface,
		)
		defer delete(supported_formats)
		renderer.surface_format = supported_formats[0] // default in case preferred value not supported
		for supported_format in supported_formats {
			if supported_format.format == .B8G8R8A8_SRGB &&
			   supported_format.colorSpace == .SRGB_NONLINEAR {
				renderer.surface_format = supported_format
				break
			}
		}

		supported_modes := get_physical_device_surface_present_modes(
			renderer.physical_device,
			renderer.surface,
		)
		defer delete(supported_modes)
		renderer.surface_present_mode = .FIFO // default in case preferred value not supported
		for supported_mode in supported_modes {
			if supported_mode == .MAILBOX {
				renderer.surface_present_mode = supported_mode
				break
			}
		}
	}

	setup_new_swapchain(&renderer)


	{ 	// TODO - create descriptor sets for image sampler(s) and uniform buffer object(s)
	}

	{ 	// create graphics pipeline
		vertex_shader_code, vertex_shader_read_ok := os.read_entire_file("vert.spv")
		if !vertex_shader_read_ok {
			panic("failed to read vertex shader code")
		}
		fragment_shader_code, fragment_shader_read_ok := os.read_entire_file("frag.spv")
		if !fragment_shader_read_ok {
			panic("failed to read fragment shader code")
		}
		vertex_create_info := vk.ShaderModuleCreateInfo {
			sType    = .SHADER_MODULE_CREATE_INFO,
			pCode    = cast(^u32)raw_data(vertex_shader_code),
			codeSize = len(vertex_shader_code),
		}
		fragment_create_info := vk.ShaderModuleCreateInfo {
			sType    = .SHADER_MODULE_CREATE_INFO,
			pCode    = cast(^u32)raw_data(fragment_shader_code),
			codeSize = len(fragment_shader_code),
		}
		vertex_shader_module: vk.ShaderModule
		fragment_shader_module: vk.ShaderModule
		if vk.CreateShaderModule(
			   renderer.device,
			   &vertex_create_info,
			   nil,
			   &vertex_shader_module,
		   ) !=
		   .SUCCESS {
			panic("failed to create vertex shader module")
		}
		if vk.CreateShaderModule(
			   renderer.device,
			   &fragment_create_info,
			   nil,
			   &fragment_shader_module,
		   ) !=
		   .SUCCESS {
			panic("failed to create fragment shader module")
		}
		defer {
			vk.DestroyShaderModule(renderer.device, vertex_shader_module, nil)
			vk.DestroyShaderModule(renderer.device, fragment_shader_module, nil)
		}
		vertex_shader_stage_create_info := vk.PipelineShaderStageCreateInfo {
			sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage  = {.VERTEX},
			module = vertex_shader_module,
			pName  = "main",
		}
		fragment_shader_stage_create_info := vk.PipelineShaderStageCreateInfo {
			sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage  = {.FRAGMENT},
			module = fragment_shader_module,
			pName  = "main",
		}
		shader_stage_create_infos := []vk.PipelineShaderStageCreateInfo {
			vertex_shader_stage_create_info,
			fragment_shader_stage_create_info,
		}
		dynamic_states := []vk.DynamicState{.VIEWPORT, .SCISSOR}
		dynamic_state_create_info := vk.PipelineDynamicStateCreateInfo {
			sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
			dynamicStateCount = cast(u32)len(dynamic_states),
			pDynamicStates    = raw_data(dynamic_states),
		}
		vertex_input_state_create_info := vk.PipelineVertexInputStateCreateInfo {
			sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
			vertexBindingDescriptionCount   = 1,
			pVertexBindingDescriptions      = &vertex_input_binding_description,
			vertexAttributeDescriptionCount = 1,
			pVertexAttributeDescriptions    = &vertex_input_attribute_description,
		}
		input_assembly_state_create_info := vk.PipelineInputAssemblyStateCreateInfo {
			sType                  = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
			topology               = .TRIANGLE_LIST,
			primitiveRestartEnable = false,
		}
		pipeline_viewport_state_create_info := vk.PipelineViewportStateCreateInfo {
			sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
			viewportCount = 1,
			scissorCount  = 1,
		}
		pipeline_rasterization_state_create_info := vk.PipelineRasterizationStateCreateInfo {
			sType                   = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
			depthClampEnable        = false,
			rasterizerDiscardEnable = false,
			polygonMode             = .FILL,
			lineWidth               = 1,
			cullMode                = {.BACK},
			frontFace               = .CLOCKWISE,
			depthBiasEnable         = false,
		}
		pipeline_multisample_state_create_info := vk.PipelineMultisampleStateCreateInfo {
			sType                = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
			sampleShadingEnable  = false,
			rasterizationSamples = {._1},
		}
		pipeline_color_blend_attachment_state := vk.PipelineColorBlendAttachmentState {
			colorWriteMask = {.R, .G, .B, .A},
			blendEnable    = false,
		}
		pipeline_color_blend_state_create_info := vk.PipelineColorBlendStateCreateInfo {
			sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
			logicOpEnable   = false,
			attachmentCount = 1,
			pAttachments    = &pipeline_color_blend_attachment_state,
		}
		pipeline_layout_create_info := vk.PipelineLayoutCreateInfo {
			sType          = .PIPELINE_LAYOUT_CREATE_INFO,
			setLayoutCount = 0,
			pSetLayouts    = nil,
		}
		if vk.CreatePipelineLayout(
			   renderer.device,
			   &pipeline_layout_create_info,
			   nil,
			   &renderer.pipeline_layout,
		   ) !=
		   .SUCCESS {
			panic("failed to create pipeline layout")
		}
		color_attachment_description := vk.AttachmentDescription {
			format         = renderer.surface_format.format,
			samples        = {._1},
			loadOp         = .CLEAR,
			storeOp        = .STORE,
			stencilLoadOp  = .DONT_CARE,
			stencilStoreOp = .DONT_CARE,
			initialLayout  = .UNDEFINED,
			finalLayout    = .PRESENT_SRC_KHR,
		}
		color_attachment_ref := vk.AttachmentReference {
			attachment = 0,
			layout     = .COLOR_ATTACHMENT_OPTIMAL,
		}
		subpass_description := vk.SubpassDescription {
			colorAttachmentCount = 1,
			pColorAttachments    = &color_attachment_ref,
		}
		subpass_dependency := vk.SubpassDependency {
			srcSubpass    = vk.SUBPASS_EXTERNAL,
			dstSubpass    = 0,
			srcStageMask  = {.COLOR_ATTACHMENT_OUTPUT},
			srcAccessMask = {},
			dstStageMask  = {.COLOR_ATTACHMENT_OUTPUT},
			dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
		}
		render_pass_create_info := vk.RenderPassCreateInfo {
			sType           = .RENDER_PASS_CREATE_INFO,
			attachmentCount = 1,
			pAttachments    = &color_attachment_description,
			subpassCount    = 1,
			pSubpasses      = &subpass_description,
			dependencyCount = 1,
			pDependencies   = &subpass_dependency,
		}
		if vk.CreateRenderPass(
			   renderer.device,
			   &render_pass_create_info,
			   nil,
			   &renderer.render_pass,
		   ) !=
		   .SUCCESS {
			panic("failed to create render pass")
		}
		graphics_pipeline_create_info := vk.GraphicsPipelineCreateInfo {
			sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
			stageCount          = 2,
			pStages             = raw_data(shader_stage_create_infos),
			pVertexInputState   = &vertex_input_state_create_info,
			pInputAssemblyState = &input_assembly_state_create_info,
			pViewportState      = &pipeline_viewport_state_create_info,
			pRasterizationState = &pipeline_rasterization_state_create_info,
			pMultisampleState   = &pipeline_multisample_state_create_info,
			pDepthStencilState  = nil,
			pColorBlendState    = &pipeline_color_blend_state_create_info,
			pDynamicState       = &dynamic_state_create_info,
			layout              = renderer.pipeline_layout,
			renderPass          = renderer.render_pass,
			subpass             = 0,
		}
		if vk.CreateGraphicsPipelines(
			   renderer.device,
			   0,
			   1,
			   &graphics_pipeline_create_info,
			   nil,
			   &renderer.graphics_pipeline,
		   ) !=
		   .SUCCESS {
			panic("failed to create graphics pipeline")
		}
	}

	setup_new_framebuffers(&renderer)

	{ 	// create command pool
		create_info := vk.CommandPoolCreateInfo {
			sType            = .COMMAND_POOL_CREATE_INFO,
			flags            = {.RESET_COMMAND_BUFFER},
			queueFamilyIndex = renderer.queue_family_index,
		}
		if vk.CreateCommandPool(renderer.device, &create_info, nil, &renderer.command_pool) !=
		   .SUCCESS {
			panic("failed to create command pool")
		}
	}

	{ 	// create command buffers
    allocate_info := vk.CommandBufferAllocateInfo {
      sType = .COMMAND_BUFFER_ALLOCATE_INFO,
      commandPool = renderer.command_pool,
      level = .PRIMARY,
      commandBufferCount = len(renderer.command_buffers),
    }
    if vk.AllocateCommandBuffers(renderer.device, &allocate_info, &renderer.command_buffers[0]) != .SUCCESS {
      panic("failed to allocate command buffers")
    }
	}

	{ 	// TODO - create texture image and image view
	}

	{ 	// TODO - create texture sampler
	}

	{ 	// create vertex buffer, allocate and bind memory, and persistently map memory
		buffer_size := cast(vk.DeviceSize)(size_of(vertices[0]) * len(vertices))
		renderer.vertex_buffer, renderer.vertex_buffer_memory = create_buffer(
			&renderer,
			buffer_size,
			{.VERTEX_BUFFER},
			{.HOST_VISIBLE, .HOST_COHERENT},
		)
    vk.MapMemory(renderer.device, renderer.vertex_buffer_memory, 0, buffer_size, {}, &renderer.vertex_buffer_mapped)
    intrinsics.mem_copy_non_overlapping(renderer.vertex_buffer_mapped, raw_data(vertices), buffer_size)
	}

	{ 	// create index buffer, alloater and bind memory, and persistently map memory
    buffer_size := cast(vk.DeviceSize)(size_of(indices[0]) * len(indices))
    renderer.index_buffer, renderer.index_buffer_memory = create_buffer(
      &renderer,
      buffer_size,
      {.INDEX_BUFFER},
      {.HOST_VISIBLE, .HOST_COHERENT},
    )
    vk.MapMemory(renderer.device, renderer.index_buffer_memory, 0, buffer_size, {}, &renderer.index_buffer_mapped)
    intrinsics.mem_copy_non_overlapping(renderer.index_buffer_mapped, raw_data(indices), buffer_size)
	}

	{ 	// TODO - create uniform buffers
	}

	{ 	// TODO - create descriptor pool
	}

	{ 	// TODO - allocate and configure descriptor sets
	}

	{ 	// create sync objects
    semaphore_create_info := vk.SemaphoreCreateInfo {
      sType = .SEMAPHORE_CREATE_INFO,
    }
    fence_create_info := vk.FenceCreateInfo {
      sType = .FENCE_CREATE_INFO,
      flags = {.SIGNALED},
    }
    for i in 0..< MAX_FRAMES_IN_FLIGHT {
      if vk.CreateSemaphore(
        renderer.device,
        &semaphore_create_info,
        nil,
        &renderer.sync_semaphores_image_available[i],
      ) != .SUCCESS {
        panic("failed to create image available semaphore")
      }
      if vk.CreateSemaphore(
        renderer.device,
        &semaphore_create_info,
        nil,
        &renderer.sync_semaphores_render_finished[i],
      ) != .SUCCESS {
        panic("failed to create render finished semaphore")
      }
      if vk.CreateFence(
        renderer.device,
        &fence_create_info,
        nil,
        &renderer.sync_fences_in_flight[i],
      ) != .SUCCESS {
        panic("failed to create in-flight fence")
      }
    }
	}
	return renderer
}

deinit_renderer :: proc(renderer: Renderer) {
	fmt.println("deinit_renderer")
}

setup_new_swapchain :: proc(renderer: ^Renderer) {
	surface_capabilities: vk.SurfaceCapabilitiesKHR
	if res := vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
		renderer.physical_device,
		renderer.surface,
		&surface_capabilities,
	); res != vk.Result.SUCCESS {
		panic("get physical device surface capabilities failed")
	}
	{ 	// set swapchain extent
		// special value, indicates size will be determined by extent of a swapchain targeting the surface
		if surface_capabilities.currentExtent.width == max(u32) {
			width, height := glfw.GetFramebufferSize(renderer.window)
			extent: vk.Extent2D = {
				width  = clamp(
					cast(u32)width,
					surface_capabilities.minImageExtent.width,
					surface_capabilities.maxImageExtent.width,
				),
				height = clamp(
					cast(u32)height,
					surface_capabilities.minImageExtent.height,
					surface_capabilities.maxImageExtent.height,
				),
			}
			renderer.surface_extent = extent
		} else {
			// default case, set swapchain extent to match the screens current extent
			renderer.surface_extent = surface_capabilities.currentExtent
		}
	}

	{ 	// create swapchain
		swapchain_create_info := vk.SwapchainCreateInfoKHR {
			sType            = .SWAPCHAIN_CREATE_INFO_KHR,
			surface          = renderer.surface,
			oldSwapchain     = 0, // VK_NULL_HANDLE
			imageFormat      = renderer.surface_format.format,
			imageColorSpace  = renderer.surface_format.colorSpace,
			presentMode      = renderer.surface_present_mode,
			imageExtent      = renderer.surface_extent,
			minImageCount    = surface_capabilities.minImageCount + 1,
			imageUsage       = {.COLOR_ATTACHMENT},
			imageArrayLayers = 1,
			imageSharingMode = .EXCLUSIVE,
			compositeAlpha   = {.OPAQUE},
			clipped          = true,
			preTransform     = surface_capabilities.currentTransform,
		}
		if res := vk.CreateSwapchainKHR(
			renderer.device,
			&swapchain_create_info,
			nil,
			&renderer.swapchain,
		); res != vk.Result.SUCCESS {
			panic("create swapchain failed")
		}
	}

	{ 	// get swapchain images
		count: u32
		vk.GetSwapchainImagesKHR(renderer.device, renderer.swapchain, &count, nil)
		renderer.swapchain_images = make([]vk.Image, count)
		if vk.GetSwapchainImagesKHR(
			   renderer.device,
			   renderer.swapchain,
			   &count,
			   raw_data(renderer.swapchain_images),
		   ) !=
		   .SUCCESS {
			panic("failed to get swapchain images")
		}
	}

	{ 	// create swapchain image views
		renderer.swapchain_image_views = make([]vk.ImageView, len(renderer.swapchain_images))
		for swapchain_image, i in renderer.swapchain_images {
			image_view_create_info := vk.ImageViewCreateInfo {
				sType = .IMAGE_VIEW_CREATE_INFO,
				image = swapchain_image,
				viewType = .D2,
				format = renderer.surface_format.format,
				components = {r = .IDENTITY, g = .IDENTITY, b = .IDENTITY, a = .IDENTITY},
				subresourceRange = {
					aspectMask = {.COLOR},
					baseMipLevel = 0,
					levelCount = 1,
					baseArrayLayer = 0,
					layerCount = 1,
				},
			}
			if res := vk.CreateImageView(
				renderer.device,
				&image_view_create_info,
				nil,
				&renderer.swapchain_image_views[i],
			); res != vk.Result.SUCCESS {
				panic("create image view failed")
			}
		}
	}
}

setup_new_framebuffers :: proc(renderer: ^Renderer) {
	renderer.swapchain_framebuffers = make([]vk.Framebuffer, len(renderer.swapchain_image_views))
	for image_view, i in renderer.swapchain_image_views {
		create_info := vk.FramebufferCreateInfo {
			sType           = .FRAMEBUFFER_CREATE_INFO,
			renderPass      = renderer.render_pass,
			attachmentCount = 1,
			pAttachments    = &renderer.swapchain_image_views[i],
			width           = renderer.surface_extent.width,
			height          = renderer.surface_extent.height,
			layers          = 1,
		}
		if vk.CreateFramebuffer(
			   renderer.device,
			   &create_info,
			   nil,
			   &renderer.swapchain_framebuffers[i],
		   ) !=
		   .SUCCESS {
			panic("failed to create framebuffer")
		}
	}
}

create_buffer :: proc(
	renderer: ^Renderer,
	size: vk.DeviceSize,
	usage: vk.BufferUsageFlags,
	memory_properties: vk.MemoryPropertyFlags,
) -> (
	buffer: vk.Buffer,
	buffer_memory: vk.DeviceMemory,
) {
	create_info := vk.BufferCreateInfo {
		sType       = .BUFFER_CREATE_INFO,
		size        = size,
		usage       = usage,
		sharingMode = .EXCLUSIVE,
	}
	if vk.CreateBuffer(renderer.device, &create_info, nil, &buffer) != .SUCCESS {
		panic("failed to create buffer")
	}
	memory_requirements: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(renderer.device, buffer, &memory_requirements)
	allocate_info := vk.MemoryAllocateInfo {
		sType           = .MEMORY_ALLOCATE_INFO,
		allocationSize  = memory_requirements.size,
		memoryTypeIndex = find_memory_type(
			renderer,
			memory_requirements.memoryTypeBits,
			memory_properties,
		),
	}
	if vk.AllocateMemory(renderer.device, &allocate_info, nil, &buffer_memory) != .SUCCESS {
		panic("failed to allocate buffer memory")
	}
	vk.BindBufferMemory(renderer.device, buffer, buffer_memory, 0)
	return buffer, buffer_memory
}

find_memory_type :: proc(
	renderer: ^Renderer,
	type_filter: u32,
	properties: vk.MemoryPropertyFlags,
) -> u32 {
	available_memory_properties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(renderer.physical_device, &available_memory_properties)
	for i in 0 ..< available_memory_properties.memoryTypeCount {
		if type_filter & (1 << i) != 0 &&
		   available_memory_properties.memoryTypes[i].propertyFlags >= properties {
			return i
		}
	}
	panic("failed to find suitable memory type")
}

recreate_swapchain :: proc(renderer: ^Renderer) {
  width, height := glfw.GetFramebufferSize(renderer.window)
  for width == 0 || height == 0 {
    width, height := glfw.GetFramebufferSize(renderer.window)
    glfw.WaitEvents()
  }

  vk.DeviceWaitIdle(renderer.device)
  clean_up_swapchain_and_framebuffers(renderer)
  setup_new_swapchain(renderer)
  setup_new_framebuffers(renderer)
}

clean_up_swapchain_and_framebuffers :: proc(renderer: ^Renderer) {
  for framebuffer in renderer.swapchain_framebuffers {
    vk.DestroyFramebuffer(renderer.device, framebuffer, nil)
  }
  delete(renderer.swapchain_framebuffers)
  for image_view in renderer.swapchain_image_views {
    vk.DestroyImageView(renderer.device, image_view, nil)
  }
  delete(renderer.swapchain_images)
  delete(renderer.swapchain_image_views)
  vk.DestroySwapchainKHR(renderer.device, renderer.swapchain, nil)
}
