# Writes the Odin tables for the packed animals (see pack_quadruped.py) from
# their assets/<name>/info.json: bones, which half of the body each bone
# moves with, material groups, animations and sockets.
import json, sys

# Bones that move with the front half of the body (the rest with the rear):
# when he holds an animal, each half follows its own frame (see draw.odin).
FRONT = ("Torso2", "Torso3", "Neck", "Head", "Ear", "Front", "IKFront", "FF.", "PoleTarget.")

def front(name):
    return name.startswith(FRONT)

def vec(v):
    return "{%s}" % ", ".join("%g" % round(x, 4) for x in v)

# An animal given as name:FLAG is compiled in only when that build switch
# is on (its data is left out of the game otherwise).
args = sys.argv[1:]
names = [a.split(":")[0] for a in args]
flags = {a.split(":")[0]: a.split(":")[1] for a in args if ":" in a}
infos = [json.load(open("assets/%s/info.json" % n)) for n in names]
out = []
w = out.append
w("package game")
w("")
w("// Made by tools/pack_quadrupeds.sh from the animated animal pack: do not edit.")
w("")
w("Quad_Kind :: enum {%s}" % ", ".join(n.capitalize() for n in names))
w("QUAD_MAX_BONES :: %d" % max(len(i["bones"]) for i in infos))
w("QUAD_MAX_VERTS :: %d" % max(sum(g["count"] for g in i["groups"]) for i in infos))
w("QUAD_MAX_GROUPS :: %d" % max(len(i["groups"]) for i in infos))
w("")
for n in names:
    if n in flags:
        u = n.upper()
        w("when %s {" % flags[n])
        w('\tQUAD_%s_MESH := #load("../../assets/%s/mesh.bin", []Quad_Vertex)' % (u, n))
        w('\tQUAD_%s_REST := #load("../../assets/%s/rest.bin", [][16]f32)' % (u, n))
        w('\tQUAD_%s_FRAMES := #load("../../assets/%s/frames.bin", [][12]f32)' % (u, n))
        w("} else {")
        w("\tQUAD_%s_MESH: []Quad_Vertex" % u)
        w("\tQUAD_%s_REST: [][16]f32" % u)
        w("\tQUAD_%s_FRAMES: [][12]f32" % u)
        w("}")
        w("")
w("QUAD_MODELS := [Quad_Kind]Quad_Model {")
for n, i in zip(names, infos):
    idx = {b: k for k, b in enumerate(i["bones"])}
    w("\t.%s = {" % n.capitalize())
    w('\t\tname = "%s", // from %s' % (n, i["source"]))
    w("\t\tbones = []string{%s}," % ", ".join('"%s"' % b for b in i["bones"]))
    w("\t\tparents = []int{%s}," % ", ".join(str(p) for p in i["parents"]))
    w("\t\tfront = []bool{%s}," % ", ".join("true" if front(b) else "false" for b in i["bones"]))
    w("\t\tgroups = []Quad_Group{%s}," % ", ".join('{"%s", %d, %d}' % (g["name"], g["first"], g["count"]) for g in i["groups"]))
    w("\t\tclips = []Quad_Clip{%s}," % ", ".join('{"%s", %d, %d, %g, %s, %g}' % (c["name"], c["first"], c["count"], c["fps"], "true" if c["loop"] else "false", round(c["stride"], 4)) for c in i["clips"]))
    w("\t\tsockets = []Quad_Socket{%s}," % ", ".join('{"%s", %s, %s, %d}' % (k, vec(s["pos"]), vec(s.get("normal", [0, 0, 1])), idx[s["bone"]]) for k, s in sorted(i["sockets"].items())))
    if n in flags:
        u = n.upper()
        w("\t\tmesh = QUAD_%s_MESH," % u)
        w("\t\trest = QUAD_%s_REST," % u)
        w("\t\tframes = QUAD_%s_FRAMES," % u)
    else:
        w('\t\tmesh = #load("../../assets/%s/mesh.bin", []Quad_Vertex),' % n)
        w('\t\trest = #load("../../assets/%s/rest.bin", [][16]f32),' % n)
        w('\t\tframes = #load("../../assets/%s/frames.bin", [][12]f32),' % n)
    w("\t},")
w("}")
print("\n".join(out))
