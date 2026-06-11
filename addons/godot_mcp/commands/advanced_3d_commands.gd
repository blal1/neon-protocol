@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

func get_commands() -> Dictionary:
	return {
		"setup_skeleton_3d":     _setup_skeleton_3d,
		"set_bone_pose":         _set_bone_pose,
		"setup_csg_shape":       _setup_csg_shape,
		"boolean_csg":           _boolean_csg,
		"setup_multimesh":       _setup_multimesh,
		"setup_vehicle_body":    _setup_vehicle_body,
		"setup_spring_arm":      _setup_spring_arm,
		"setup_path_3d":         _setup_path_3d,
		"setup_joint_3d":        _setup_joint_3d,
		"setup_soft_body":       _setup_soft_body,
		"setup_decal":           _setup_decal,
		"setup_fog_volume":      _setup_fog_volume,
		"setup_occluder":        _setup_occluder,
		"setup_voxel_gi":        _setup_voxel_gi,
		"setup_reflection_probe": _setup_reflection_probe,
	}

func _v3(params: Dictionary, key: String, def: Vector3) -> Vector3:
	if not params.has(key): return def
	var v = params[key]
	if v is Dictionary: return Vector3(float(v.get("x",def.x)), float(v.get("y",def.y)), float(v.get("z",def.z)))
	if v is Array and v.size()>=3: return Vector3(float(v[0]),float(v[1]),float(v[2]))
	return def

func _col(params: Dictionary, key: String, def: Color) -> Color:
	if not params.has(key): return def
	var v = params[key]
	if v is String: return Color(v)
	if v is Dictionary: return Color(float(v.get("r",def.r)),float(v.get("g",def.g)),float(v.get("b",def.b)),float(v.get("a",def.a)))
	return def

func _add(node: Node, parent: Node, root: Node, label: String) -> void:
	var ur := get_undo_redo()
	ur.create_action(label)
	ur.add_do_method(parent,"add_child",node)
	ur.add_do_method(node,"set_owner",root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent,"remove_child",node)
	ur.commit_action()

func _pr(params: Dictionary) -> Array:
	var root := get_edited_root()
	if root == null: return [null,null,error_no_scene()]
	var pp: String = optional_string(params,"parent_path",".")
	var parent := find_node_by_path(pp)
	if parent == null: return [null,null,error_not_found("Parent '%s'" % pp)]
	return [parent,root,null]

## 1. setup_skeleton_3d
func _setup_skeleton_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var skel := Skeleton3D.new()
	skel.name = optional_string(params,"name","Skeleton3D")
	for b in params.get("bones",[]):
		if not b is Dictionary: continue
		var idx := skel.add_bone(str(b.get("name","Bone")))
		if b.has("parent_index"): skel.set_bone_parent(idx, int(b["parent_index"]))
		var rest := Transform3D()
		rest.origin = _v3(b,"position",Vector3.ZERO)
		skel.set_bone_rest(idx, rest)
	_add(skel,parent,root,"MCP: Add Skeleton3D")
	return success({"node_path":str(root.get_path_to(skel)),"bone_count":skel.get_bone_count()})

## 2. set_bone_pose
func _set_bone_pose(params: Dictionary) -> Dictionary:
	var res := require_string(params,"node_path"); if res[1]: return res[1]
	var node := find_node_by_path(res[0])
	if node == null: return error_not_found("Node '%s'" % res[0])
	if not node is Skeleton3D: return error_invalid_params("Node is not a Skeleton3D")
	var skel := node as Skeleton3D
	var bone_id: int = -1
	if params.has("bone_index"): bone_id = int(params["bone_index"])
	elif params.has("bone_name"): bone_id = skel.find_bone(str(params["bone_name"]))
	if bone_id < 0 or bone_id >= skel.get_bone_count(): return error_invalid_params("Invalid bone_index or bone_name")
	var t := skel.get_bone_pose(bone_id)
	t.origin = _v3(params,"position",t.origin)
	skel.set_bone_pose_position(bone_id, _v3(params,"position",t.origin))
	if params.has("rotation"):
		var r := _v3(params,"rotation",Vector3.ZERO)
		skel.set_bone_pose_rotation(bone_id, Quaternion.from_euler(r * PI/180.0))
	if params.has("scale"):
		skel.set_bone_pose_scale(bone_id, _v3(params,"scale",Vector3.ONE))
	return success({"bone_index":bone_id,"bone_name":skel.get_bone_name(bone_id)})

## 3. setup_csg_shape
func _setup_csg_shape(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var shape_type: String = optional_string(params,"shape_type","CSGBox3D")
	var node: CSGShape3D
	match shape_type:
		"CSGBox3D":      node = CSGBox3D.new()
		"CSGSphere3D":   node = CSGSphere3D.new()
		"CSGCylinder3D": node = CSGCylinder3D.new()
		"CSGTorus3D":    node = CSGTorus3D.new()
		"CSGMesh3D":     node = CSGMesh3D.new()
		"CSGCombiner3D": node = CSGCombiner3D.new()
		_: return error_invalid_params("Unknown shape_type: %s" % shape_type)
	node.name = optional_string(params,"name",shape_type)
	if node is CSGBox3D: (node as CSGBox3D).size = _v3(params,"size",Vector3.ONE)
	elif node is CSGSphere3D: (node as CSGSphere3D).radius = float(params.get("radius",0.5))
	elif node is CSGCylinder3D:
		(node as CSGCylinder3D).radius = float(params.get("radius",0.5))
		(node as CSGCylinder3D).height = float(params.get("height",1.0))
	node.position = _v3(params,"position",Vector3.ZERO)
	node.use_collision = optional_bool(params,"use_collision",false)
	_add(node,parent,root,"MCP: Add %s" % shape_type)
	return success({"node_path":str(root.get_path_to(node)),"shape_type":shape_type})

## 4. boolean_csg
func _boolean_csg(params: Dictionary) -> Dictionary:
	var res := require_string(params,"node_path"); if res[1]: return res[1]
	var node := find_node_by_path(res[0])
	if node == null: return error_not_found("Node '%s'" % res[0])
	if not node is CSGShape3D: return error_invalid_params("Node is not a CSGShape3D")
	var csg := node as CSGShape3D
	var op_str: String = optional_string(params,"operation","union")
	match op_str.to_lower():
		"union":        csg.operation = CSGShape3D.OPERATION_UNION
		"intersection": csg.operation = CSGShape3D.OPERATION_INTERSECTION
		"subtraction":  csg.operation = CSGShape3D.OPERATION_SUBTRACTION
		_: return error_invalid_params("operation must be union, intersection, or subtraction")
	return success({"node_path":res[0],"operation":op_str})

## 5. setup_multimesh
func _setup_multimesh(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var mmi := MultiMeshInstance3D.new()
	mmi.name = optional_string(params,"name","MultiMeshInstance3D")
	var mm := MultiMesh.new()
	mm.instance_count = optional_int(params,"instance_count",10)
	mm.transform_format = MultiMesh.TRANSFORM_3D
	if params.has("mesh_type"):
		var mesh_map := {"BoxMesh":BoxMesh.new(),"SphereMesh":SphereMesh.new(),"CylinderMesh":CylinderMesh.new()}
		var mt: String = params["mesh_type"]
		if mesh_map.has(mt): mm.mesh = mesh_map[mt]
	elif params.has("mesh_path"):
		if ResourceLoader.exists(str(params["mesh_path"])): mm.mesh = load(str(params["mesh_path"]))
	mmi.multimesh = mm
	mmi.position = _v3(params,"position",Vector3.ZERO)
	_add(mmi,parent,root,"MCP: Add MultiMeshInstance3D")
	return success({"node_path":str(root.get_path_to(mmi)),"instance_count":mm.instance_count})

## 6. setup_vehicle_body
func _setup_vehicle_body(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var vb := VehicleBody3D.new()
	vb.name = optional_string(params,"name","VehicleBody3D")
	vb.mass = float(params.get("mass",800.0))
	vb.engine_force = float(params.get("engine_force",0.0))
	_add(vb,parent,root,"MCP: Add VehicleBody3D")
	var wheel_paths: Array = []
	var wheel_positions: Array = params.get("wheel_positions",[
		{"x":1.2,"y":-0.5,"z":1.5},{"x":-1.2,"y":-0.5,"z":1.5},
		{"x":1.2,"y":-0.5,"z":-1.5},{"x":-1.2,"y":-0.5,"z":-1.5}
	])
	for i in range(wheel_positions.size()):
		var wp = wheel_positions[i]
		var w := VehicleWheel3D.new()
		w.name = "Wheel%d" % i
		w.position = _v3(wp if wp is Dictionary else {},"",Vector3(float(wp.get("x",0)) if wp is Dictionary else 0,float(wp.get("y",-0.5)) if wp is Dictionary else -0.5,float(wp.get("z",0)) if wp is Dictionary else 0))
		w.use_as_traction = i < 2
		w.use_as_steering = i < 2
		vb.add_child(w); w.owner = root
		wheel_paths.append(str(vb.get_path_to(w)))
	return success({"node_path":str(root.get_path_to(vb)),"wheels":wheel_paths})

## 7. setup_spring_arm
func _setup_spring_arm(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var sa := SpringArm3D.new()
	sa.name = optional_string(params,"name","SpringArm3D")
	sa.spring_length = float(params.get("spring_length",3.0))
	sa.collision_mask = optional_int(params,"collision_mask",1)
	sa.margin = float(params.get("margin",0.01))
	sa.position = _v3(params,"position",Vector3.ZERO)
	_add(sa,parent,root,"MCP: Add SpringArm3D")
	return success({"node_path":str(root.get_path_to(sa)),"spring_length":sa.spring_length})

## 8. setup_path_3d
func _setup_path_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var path_node := Path3D.new()
	path_node.name = optional_string(params,"name","Path3D")
	var curve := Curve3D.new()
	for p in params.get("points",[]):
		var pos := _v3(p if p is Dictionary else {},"position",Vector3.ZERO)
		var ti  := _v3(p if p is Dictionary else {},"in",Vector3.ZERO)
		var to  := _v3(p if p is Dictionary else {},"out",Vector3.ZERO)
		curve.add_point(pos,ti,to)
	path_node.curve = curve
	_add(path_node,parent,root,"MCP: Add Path3D")
	var added: Array = []
	if optional_bool(params,"add_follow",false):
		var pf := PathFollow3D.new(); pf.name = "PathFollow3D"
		path_node.add_child(pf); pf.owner = root; added.append("PathFollow3D")
	return success({"node_path":str(root.get_path_to(path_node)),"point_count":curve.point_count,"children":added})

## 9. setup_joint_3d
func _setup_joint_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var joint_type: String = optional_string(params,"joint_type","HingeJoint3D")
	var joint: Joint3D
	match joint_type:
		"HingeJoint3D":       joint = HingeJoint3D.new()
		"SliderJoint3D":      joint = SliderJoint3D.new()
		"ConeTwistJoint3D":   joint = ConeTwistJoint3D.new()
		"Generic6DOFJoint3D": joint = Generic6DOFJoint3D.new()
		"PinJoint3D":         joint = PinJoint3D.new()
		_: return error_invalid_params("Unknown joint_type: %s" % joint_type)
	joint.name = optional_string(params,"name",joint_type)
	joint.position = _v3(params,"position",Vector3.ZERO)
	if params.has("node_a"): joint.node_a = NodePath(str(params["node_a"]))
	if params.has("node_b"): joint.node_b = NodePath(str(params["node_b"]))
	_add(joint,parent,root,"MCP: Add %s" % joint_type)
	return success({"node_path":str(root.get_path_to(joint)),"joint_type":joint_type})

## 10. setup_soft_body
func _setup_soft_body(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var sb := SoftBody3D.new()
	sb.name = optional_string(params,"name","SoftBody3D")
	sb.simulation_precision = optional_int(params,"simulation_precision",5)
	sb.total_mass = float(params.get("mass",1.0))
	sb.linear_stiffness = float(params.get("linear_stiffness",0.99))
	sb.pressure_coefficient = float(params.get("pressure",0.0))
	sb.damping_coefficient = float(params.get("damping",0.01))
	if params.has("mesh_path"):
		if ResourceLoader.exists(str(params["mesh_path"])):
			var m: Resource = load(str(params["mesh_path"]))
			if m is Mesh: sb.mesh = m
	_add(sb,parent,root,"MCP: Add SoftBody3D")
	return success({"node_path":str(root.get_path_to(sb))})

## 11. setup_decal
func _setup_decal(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var d := Decal.new()
	d.name = optional_string(params,"name","Decal")
	d.size = _v3(params,"size",Vector3(1,1,1))
	d.position = _v3(params,"position",Vector3.ZERO)
	d.rotation_degrees = _v3(params,"rotation",Vector3.ZERO)
	for ch in ["albedo","normal","orm","emission"]:
		if params.has(ch+"_texture"):
			var tp: String = params[ch+"_texture"]
			if ResourceLoader.exists(tp): d.set("texture_%s" % ch, load(tp))
	d.emission_energy = float(params.get("emission_energy",1.0))
	d.upper_fade = float(params.get("upper_fade",0.3))
	d.lower_fade = float(params.get("lower_fade",0.3))
	_add(d,parent,root,"MCP: Add Decal")
	return success({"node_path":str(root.get_path_to(d))})

## 12. setup_fog_volume
func _setup_fog_volume(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var fv := FogVolume.new()
	fv.name = optional_string(params,"name","FogVolume")
	fv.size = _v3(params,"size",Vector3(2,2,2))
	fv.position = _v3(params,"position",Vector3.ZERO)
	var shape_str: String = optional_string(params,"shape","box")
	match shape_str.to_lower():
		"sphere":    fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		"ellipsoid": fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		"cone":      fv.shape = RenderingServer.FOG_VOLUME_SHAPE_CONE
		"cylinder":  fv.shape = RenderingServer.FOG_VOLUME_SHAPE_CYLINDER
		_:           fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	var mat := FogMaterial.new()
	mat.density = float(params.get("density",1.0))
	mat.albedo  = _col(params,"color",Color(1,1,1,1))
	fv.material = mat
	_add(fv,parent,root,"MCP: Add FogVolume")
	return success({"node_path":str(root.get_path_to(fv)),"shape":shape_str})

## 13. setup_occluder
func _setup_occluder(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var oi := OccluderInstance3D.new()
	oi.name = optional_string(params,"name","OccluderInstance3D")
	oi.position = _v3(params,"position",Vector3.ZERO)
	var shape_str: String = optional_string(params,"occluder_type","box")
	var occ: Occluder3D
	match shape_str.to_lower():
		"sphere":   occ = SphereOccluder3D.new()
		"quadmesh": occ = QuadOccluder3D.new()
		_:          occ = BoxOccluder3D.new()
	if occ is BoxOccluder3D:   (occ as BoxOccluder3D).size = _v3(params,"size",Vector3.ONE)
	if occ is SphereOccluder3D: (occ as SphereOccluder3D).radius = float(params.get("radius",0.5))
	oi.occluder = occ
	oi.bake_mask = optional_int(params,"bake_mask",1)
	_add(oi,parent,root,"MCP: Add OccluderInstance3D")
	return success({"node_path":str(root.get_path_to(oi)),"occluder_type":shape_str})

## 14. setup_voxel_gi
func _setup_voxel_gi(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var vgi := VoxelGI.new()
	vgi.name = optional_string(params,"name","VoxelGI")
	vgi.size = _v3(params,"size",Vector3(20,20,20))
	vgi.position = _v3(params,"position",Vector3.ZERO)
	var subdiv_str: String = optional_string(params,"subdiv","64")
	match subdiv_str:
		"128": vgi.subdiv = VoxelGI.SUBDIV_128
		"256": vgi.subdiv = VoxelGI.SUBDIV_256
		_:     vgi.subdiv = VoxelGI.SUBDIV_64
	_add(vgi,parent,root,"MCP: Add VoxelGI")
	var msg: String = "VoxelGI added. Call bake manually via EditorScript or the editor Bake button."
	return success({"node_path":str(root.get_path_to(vgi)),"subdiv":subdiv_str,"note":msg})

## 15. setup_reflection_probe
func _setup_reflection_probe(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var rp := ReflectionProbe.new()
	rp.name = optional_string(params,"name","ReflectionProbe")
	rp.size = _v3(params,"size",Vector3(20,20,20))
	rp.origin_offset = _v3(params,"origin_offset",Vector3.ZERO)
	rp.position = _v3(params,"position",Vector3.ZERO)
	var update_str: String = optional_string(params,"update_mode","once")
	rp.update_mode = ReflectionProbe.UPDATE_ALWAYS if update_str == "always" else ReflectionProbe.UPDATE_ONCE
	rp.intensity = float(params.get("intensity",1.0))
	rp.enable_shadows = optional_bool(params,"shadows",false)
	rp.interior = optional_bool(params,"interior",false)
	_add(rp,parent,root,"MCP: Add ReflectionProbe")
	return success({"node_path":str(root.get_path_to(rp)),"update_mode":update_str})
