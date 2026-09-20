class_name EnvironmentMeshSanitizer
extends RefCounted
## Repairs silent static-environment mesh corruption before batching.

static var _cache:Dictionary={}

static func sanitize_mesh(source:Mesh)->ArrayMesh:
	if source==null:return null
	var key:int=source.get_instance_id()
	if _cache.has(key):return _cache[key]
	var result:=ArrayMesh.new()
	for surface_index in source.get_surface_count():
		if source.surface_get_primitive_type(surface_index)!=Mesh.PRIMITIVE_TRIANGLES:
			result.add_surface_from_arrays(source.surface_get_primitive_type(surface_index),source.surface_get_arrays(surface_index))
		else:
			var repaired:=sanitize_surface(source,surface_index)
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,repaired.surface_get_arrays(0))
		result.surface_set_material(surface_index,source.surface_get_material(surface_index))
	_cache[key]=result
	return result

static func sanitize_surface(source:Mesh,surface_index:int)->ArrayMesh:
	var reader:=SurfaceTool.new()
	reader.create_from(source,surface_index)
	reader.deindex()
	var raw:=reader.commit() as ArrayMesh
	var arrays:Array=raw.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
	var colours:PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
	var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
	var uv2s:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2]!=null else PackedVector2Array()
	var has_normals:=normals.size()==vertices.size()
	var has_colours:=colours.size()==vertices.size()
	var has_uv:=uvs.size()==vertices.size()
	var has_uv2:=uv2s.size()==vertices.size()
	var writer:=SurfaceTool.new();writer.begin(Mesh.PRIMITIVE_TRIANGLES)
	for base in range(0,vertices.size()-2,3):
		var a:=vertices[base];var b:=vertices[base+1];var c:=vertices[base+2]
		var face:Vector3=(b-a).cross(c-a)
		var order:Array[int]=[base,base+1,base+2]
		if has_normals and face.dot(normals[base]+normals[base+1]+normals[base+2])>0:
			order=[base,base+2,base+1]
		var fixed_uvs:Array[Vector2]=[]
		if has_uv and absf((uvs[base+1]-uvs[base]).cross(uvs[base+2]-uvs[base]))<1e-10:
			var axis:=face.abs()
			for index:int in order:
				var point:=vertices[index]
				fixed_uvs.append((Vector2(point.x,point.z) if axis.y>=axis.x and axis.y>=axis.z else (Vector2(point.z,point.y) if axis.x>=axis.z else Vector2(point.x,point.y)))*.25)
		for local_index in order.size():
			var index:int=order[local_index]
			if has_normals:writer.set_normal(normals[index])
			if has_colours:writer.set_color(colours[index])
			if has_uv:writer.set_uv(fixed_uvs[local_index] if not fixed_uvs.is_empty() else uvs[index])
			if has_uv2:writer.set_uv2(uv2s[index])
			writer.add_vertex(vertices[index])
	if not has_normals:writer.generate_normals()
	if has_uv:writer.generate_tangents()
	return writer.commit()
