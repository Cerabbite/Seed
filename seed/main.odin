package main

import "core:c"
import "core:c/libc"
import "core:strings"
import "glfw"
import gl "vendor:OpenGL"
// import "vendor:stb/truetype"

PROGRAM_NAME :: "Seed"
PROGRAM_VERSION :: "0.1.0"

GL_MAJOR_VERSION: c.int : 4
GL_MINOR_VERSION :: 6

COMMIT_HASH :: #config(COMMIT_HASH, "dev")

running: b32 = true


main :: proc() {
	// truetype.GetBakedQuad
	full_title := strings.concatenate({PROGRAM_NAME, " ", PROGRAM_VERSION, "+", COMMIT_HASH})
	c_title := strings.clone_to_cstring(full_title)
	glfw.WindowHint(glfw.RESIZABLE, 1)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	if glfw.Init() != true {
		return
	}

	defer glfw.Terminate()

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

	init()

	for (!glfw.WindowShouldClose(window) && running) {
		glfw.PollEvents()

		update()
		draw()

		glfw.SwapBuffers(window)
	}
	exit()
}

init :: proc() {

}

update :: proc() {

}

draw :: proc() {
	gl.ClearColor(0.2, 0.3, 0.3, 1.0)

	gl.Clear(gl.COLOR_BUFFER_BIT)
}

exit :: proc() {

}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	// Exit program on escape pressed
	if key == glfw.KEY_ESCAPE {
		running = false
	}
}

character_callback :: proc "c" (window: glfw.WindowHandle, codepoint: rune) {
	libc.printf("debug value: %d\n", codepoint)
}

size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	gl.Viewport(0, 0, width, height)
}
