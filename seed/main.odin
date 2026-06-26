package main

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import "glfw"
import gl "vendor:OpenGL"
import "vendor:stb/image"
import "vendor:stb/truetype"

PROGRAM_NAME :: "Seed"
PROGRAM_VERSION :: "0.1.0"

GL_MAJOR_VERSION: c.int : 4
GL_MINOR_VERSION :: 6

COMMIT_HASH :: #config(COMMIT_HASH, "dev")

running: b32 = true

main :: proc() {
	full_title := strings.concatenate({PROGRAM_NAME, " ", PROGRAM_VERSION, "+", COMMIT_HASH})
	c_title := strings.clone_to_cstring(full_title)

	if glfw.Init() != true {
		return
	}
	defer glfw.Terminate()

	glfw.WindowHint(glfw.RESIZABLE, 0)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.DECORATED, glfw.FALSE)


	window := glfw.CreateWindow(512, 512, c_title, nil, nil)
	defer glfw.DestroyWindow(window)

	if window == nil {
		return
	}

	glfw.MakeContextCurrent(window)

	glfw.SwapInterval(1)

	glfw.SetKeyCallback(window, key_callback)

	glfw.SetCharCallback(window, character_callback)

	glfw.SetFramebufferSizeCallback(window, size_callback)
	gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	init()

	font_data, err := os.read_entire_file(
		"/usr/share/fonts/truetype/ubuntu/UbuntuMono[wght].ttf",
		context.allocator,
	)
	if err != 0 {
		fmt.eprintf("Failed to read file: %v\n", err)
		return
	}

	font_atlas_width: i32 = 512
	font_atlas_height: i32 = 512
	font_atlast_bitmap := make([]byte, font_atlas_width * font_atlas_height)

	code_point_of_first_char: i32 = 32
	chars_to_include_in_font_atlas: i32 = 95
	font_size: f32 = 64.0

	chars_baked := make([]truetype.bakedchar, chars_to_include_in_font_atlas)
	packed_chars := make([]truetype.packedchar, chars_to_include_in_font_atlas)
	aligned_quads := make([]truetype.aligned_quad, chars_to_include_in_font_atlas)

	font_context: truetype.pack_context

	truetype.PackBegin(
		&font_context,
		&font_atlast_bitmap[0],
		font_atlas_width,
		font_atlas_height,
		0,
		1,
		nil,
	)

	truetype.PackFontRange(
		&font_context,
		&font_data[0],
		0,
		font_size,
		code_point_of_first_char,
		chars_to_include_in_font_atlas,
		&packed_chars[0],
	)

	truetype.PackEnd(&font_context)

	for i: i32 = 0; i < chars_to_include_in_font_atlas; i += 1 {
		unused_x: f32
		unused_y: f32

		truetype.GetPackedQuad(
			&packed_chars[0],
			font_atlas_width,
			font_atlas_height,
			i,
			&unused_x,
			&unused_y,
			&aligned_quads[i],
			false,
		)
	}

	image.write_png(
		"font_atlas.png",
		font_atlas_width,
		font_atlas_height,
		1,
		&font_atlast_bitmap[0],
		font_atlas_width,
	)

	for (!glfw.WindowShouldClose(window) && running) {
		glfw.PollEvents()

		update()

		draw()
		glfw.SwapBuffers(window)
	}
	exit()
}

init :: proc() {init_shaders()}

init_shaders :: proc() {
}

update :: proc() {}

draw :: proc() {
	gl.ClearColor(0.2, 0.3, 0.3, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)
}

exit :: proc() {}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	if key == glfw.KEY_ESCAPE {running = false}
}

character_callback :: proc "c" (window: glfw.WindowHandle, codepoint: rune) {}

size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	gl.Viewport(0, 0, width, height)
}
