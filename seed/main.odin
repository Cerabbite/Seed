package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math/linalg"
import "core:os"
import "core:strings"
import "core:unicode/utf8"
import "glfw"
import gl "vendor:OpenGL"
import "vendor:stb/truetype"

PROGRAM_NAME :: "Seed"
PROGRAM_VERSION :: "0.1.0"

GL_MAJOR_VERSION: c.int : 4
GL_MINOR_VERSION :: 6

COMMIT_HASH :: #config(COMMIT_HASH, "dev")


running: b32 = true

Vertex :: struct {
	Position:          linalg.Vector3f32,
	Color:             linalg.Vector4f32,
	TextureCoordinate: linalg.Vector2f32,
}

text_buffer: [dynamic]rune
mesh_dirty: bool = true
vao: u32
vbo: u32
shader_program: u32
vertex_count: i32
font_atlas_texture_id: u32
packed_chars: []truetype.packedchar
aligned_quads: []truetype.aligned_quad
screen_width: f32 = 512
screen_height: f32 = 512

main :: proc() {
	full_title := strings.concatenate({PROGRAM_NAME, " ", PROGRAM_VERSION, "+", COMMIT_HASH})
	c_title := strings.clone_to_cstring(full_title)

	if glfw.Init() != true {
		return
	}
	defer glfw.Terminate()

	glfw.WindowHint(glfw.RESIZABLE, 1)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)


	window := glfw.CreateWindow(i32(screen_width), i32(screen_height), c_title, nil, nil)
	defer glfw.DestroyWindow(window)

	if window == nil {
		return
	}

	glfw.MakeContextCurrent(window)

	glfw.SwapInterval(1)

	glfw.SetKeyCallback(window, key_callback)
	glfw.SetCharCallback(window, character_callback)
	glfw.SetScrollCallback(window, scroll_callback)

	glfw.SetFramebufferSizeCallback(window, size_callback)
	gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	init()

	font_data, error := os.read_entire_file(
		"/usr/share/fonts/truetype/ubuntu/UbuntuMono[wght].ttf",
		context.allocator,
	)
	defer delete(font_data)

	if error != 0 {
		fmt.eprintf("Failed to read file: %v\n", error)
		return
	}

	font_atlas_width: i32 = 512
	font_atlas_height: i32 = 512
	font_atlas_bitmap := make([]byte, font_atlas_width * font_atlas_height)
	defer delete(font_atlas_bitmap)

	code_point_of_first_char: i32 = 32
	chars_to_include_in_font_atlas: i32 = 95
	font_size: f32 = 14.0

	packed_chars = make([]truetype.packedchar, chars_to_include_in_font_atlas)
	aligned_quads = make([]truetype.aligned_quad, chars_to_include_in_font_atlas)


	font_context: truetype.pack_context

	truetype.PackBegin(
		&font_context,
		&font_atlas_bitmap[0],
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

	font_atlas_texture_id: u32
	gl.GenTextures(1, &font_atlas_texture_id)
	gl.BindTexture(gl.TEXTURE_2D, font_atlas_texture_id)

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.R8,
		font_atlas_width,
		font_atlas_height,
		0,
		gl.RED,
		gl.UNSIGNED_BYTE,
		&font_atlas_bitmap[0],
	)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)

	gl.BindTexture(gl.TEXTURE_2D, 0)

	shader_program, shader_ok := init_shaders()
	if !shader_ok {
		fmt.eprintln("Failed to create shader program")
		return
	}

	vertices: [dynamic]Vertex = build_text_mesh(
		"Hello World",
		aligned_quads,
		packed_chars,
		f32(screen_width),
		f32(screen_height),
	)

	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &vbo)

	gl.BindVertexArray(vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(Vertex), &vertices[0], gl.STATIC_DRAW)

	// Tell GL the layout of your Vertex struct
	// Position  — offset 0,  3 floats
	// Color     — offset 12, 4 floats
	// TexCoord  — offset 28, 2 floats
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), 0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 4, gl.FLOAT, false, size_of(Vertex), 12)
	gl.EnableVertexAttribArray(2)
	gl.VertexAttribPointer(2, 2, gl.FLOAT, false, size_of(Vertex), 28)

	gl.BindVertexArray(0)


	for (!glfw.WindowShouldClose(window) && running) {
		glfw.PollEvents()

		if mesh_dirty {
			text_str := utf8.runes_to_string(text_buffer[:], context.allocator)
			defer delete(text_str)

			delete(vertices)
			vertices = build_text_mesh(
				text_str,
				aligned_quads,
				packed_chars,
				screen_width,
				screen_height,
			)
			vertex_count = i32(len(vertices))

			gl.BindVertexArray(vao)
			gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
			gl.BufferData(
				gl.ARRAY_BUFFER,
				len(vertices) * size_of(Vertex),
				raw_data(vertices),
				gl.DYNAMIC_DRAW,
			)
			gl.BindVertexArray(0)

			mesh_dirty = false
		}

		draw(shader_program, vao, i32(len(vertices)), font_atlas_texture_id)
		glfw.SwapBuffers(window)
	}
	exit()
}

init :: proc() {
}

init_shaders :: proc() -> (program: u32, ok: bool) {

	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	vertex_shader_cstr := #load("blit.vert", cstring)
	gl.ShaderSource(vertex_shader, 1, &vertex_shader_cstr, nil)
	gl.CompileShader(vertex_shader)

	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	fragment_shader_cstr := #load("blit.frag", cstring)
	gl.ShaderSource(fragment_shader, 1, &fragment_shader_cstr, nil)
	gl.CompileShader(fragment_shader)

	program = gl.CreateProgram()
	gl.AttachShader(program, vertex_shader)
	gl.AttachShader(program, fragment_shader)
	gl.LinkProgram(program)
	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)

	return program, true

}

build_text_mesh :: proc(
	text: string,
	aligned_quads: []truetype.aligned_quad,
	packed_chars: []truetype.packedchar,
	screen_w: f32,
	screen_h: f32,
) -> [dynamic]Vertex {
	vertices: [dynamic]Vertex

	// Cursor position in pixels, starting top-left-ish
	x: f32 = 50
	y: f32 = screen_h / 2

	for char in text {
		idx := int(char) - 32
		if idx < 0 || idx >= len(aligned_quads) {
			continue
		}

		q := aligned_quads[idx]

		x0 := (q.x0 + x) / screen_w * 2 - 1
		x1 := (q.x1 + x) / screen_w * 2 - 1
		y0 := 1 - (q.y0 + y) / screen_h * 2
		y1 := 1 - (q.y1 + y) / screen_h * 2

		x += packed_chars[idx].xadvance

		color := linalg.Vector4f32{1, 1, 1, 1}

		// Two triangles (6 vertices) per glyph
		append(
			&vertices,
			Vertex{Position = {x0, y0, 0}, Color = color, TextureCoordinate = {q.s0, q.t0}},
		)
		append(
			&vertices,
			Vertex{Position = {x1, y0, 0}, Color = color, TextureCoordinate = {q.s1, q.t0}},
		)
		append(
			&vertices,
			Vertex{Position = {x1, y1, 0}, Color = color, TextureCoordinate = {q.s1, q.t1}},
		)
		append(
			&vertices,
			Vertex{Position = {x0, y0, 0}, Color = color, TextureCoordinate = {q.s0, q.t0}},
		)
		append(
			&vertices,
			Vertex{Position = {x1, y1, 0}, Color = color, TextureCoordinate = {q.s1, q.t1}},
		)
		append(
			&vertices,
			Vertex{Position = {x0, y1, 0}, Color = color, TextureCoordinate = {q.s0, q.t1}},
		)
	}

	return vertices
}

draw :: proc(shader_program: u32, vao: u32, vertex_count: i32, texture_id: u32) {
	gl.ClearColor(0.2, 0.3, 0.3, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	gl.UseProgram(shader_program)
	gl.BindTexture(gl.TEXTURE_2D, texture_id)
	gl.BindVertexArray(vao)
	gl.DrawArrays(gl.TRIANGLES, 0, vertex_count)
	gl.BindVertexArray(0)
}
exit :: proc() {

}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	context = runtime.default_context()
	if key == glfw.KEY_ESCAPE {
		running = false
	}
	if key == glfw.KEY_BACKSPACE && action != glfw.RELEASE {
		if len(text_buffer) > 0 do pop(&text_buffer)
		mesh_dirty = true
	}
}

scroll_callback :: proc "c" (window: glfw.WindowHandle, offset_x: f64, offset_y: f64) {

}

character_callback :: proc "c" (window: glfw.WindowHandle, codepoint: rune) {
	context = runtime.default_context()
	append(&text_buffer, codepoint)
	mesh_dirty = true
}

size_callback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
	gl.Viewport(0, 0, width, height)
	screen_width = f32(width)
	screen_height = f32(height)
	mesh_dirty = true
}
