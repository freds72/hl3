import bpy
import bmesh
import argparse
import sys
import math
from mathutils import Vector, Matrix

scene = bpy.context.scene

scene_data=[]
all_objects = [ob for ob in scene.objects if ob.layers[0] and ob.type=='MESH']
for ob in all_objects:
    obdata = ob.data
    ob_name_tokens= ob.name.split('.')
    ob_data={
        "model": ob.name if len(ob_name_tokens)==1 else ob_name_tokens[0],
        "pos":[round(ob.location.x,2), round(ob.location.z,2), round(ob.location.y,2)],
        "rotation":[round(math.degrees(ob.rotation_euler.x)/360,2)-0.5,round(math.degrees(ob.rotation_euler.z)/360,2)-0.5,round(math.degrees(ob.rotation_euler.y)/360,2)-0.5]
    }
    scene_data.append(ob_data)

print(scene_data)
