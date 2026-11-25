package game

// Made by tools/gen_data from data/tuning/prosio_look.json: do not edit; edit that file.

// How Prosio looks, apart from how the game plays: his face, and where the 36 parts of his pose sit and how big they are, which the body of shapes and the skin made in Blender (assets/prosio_base, prosio_base.odin) both follow. Whoever works on his looks works here, in assets/ and in tools/pack_assets; nothing here changes how the game plays.

// ---- face ----
// How his face moves and shows what he feels.

// how often he blinks and how long a blink lasts, in seconds (both bodies)
PROSIO_BLINK :: Vec2{3.2, 0.12}
// how quickly the meal smile fades near the end of the hold
PROSIO_FACE_SMILE_FADE :: f32(2)
// how broadly he smiles when tipsy (0 to 1)
PROSIO_FACE_TIPSY_SMILE :: f32(0.35)
// brow lift while smiling, hiccuping or passing wind
PROSIO_FACE_BROWS :: Vec3{0.3, 0.85, 0.3}

// ---- base_sculpt ----
// Where the 36 parts of his pose sit and how big they are (the skin was made at them, and the body of shapes shares its knees, arms and hands), the eyes and mouth drawn on the skin, and how the skin is outlined.

// silhouette width multiplier and depth bias to keep the hull behind tight folds
PROSIO_BASE_OUTLINE :: Vec2{0.76, 0.0012}
// height of the raised head above the old face pivot
PROSIO_BASE_HEAD_LIFT :: f32(0.185)
// fixed half-width, half-height and depth of the skull
PROSIO_BASE_HEAD_RADII :: Vec3{0.468, 0.42, 0.46}
// proportion of the head, ears and face relative to the body
PROSIO_BASE_HEAD_SCALE :: f32(0.94)
// neutral fat kg, kg from neutral to full cheeks, and maximum lean reduction
PROSIO_BASE_FACE_FAT :: Vec3{35, 58, 0.20}
// lengths from shoulder to elbow and elbow to palm in the unscaled rig
PROSIO_BASE_ARM_LENGTHS :: Vec2{0.295, 0.245}
// outward elbow bias when the palm reaches around the body
PROSIO_BASE_ARM_BIAS :: f32(0.045)
// fixed vertical half-lengths of the shoulder, biceps and elbow flesh
PROSIO_BASE_ARM_AXIAL :: Vec3{0.160, 0.137, 0.099}
// fixed vertical half-length of the knee flesh
PROSIO_BASE_KNEE_AXIAL :: f32(0.115)
// neck radii between the shoulders and jaw
PROSIO_BASE_NECK_RADII :: Vec3{0.205, 0.25, 0.195}
// height below face, share of head bob and neck depth
PROSIO_BASE_NECK_ANCHOR :: Vec3{0.40, 0.40, 0.035}
// sideways share of cheek width, elevation and depth of the ear hinge
PROSIO_BASE_EAR_ANCHOR :: Vec3{0.72, 0.313, 0.082}
// half-width, length and thickness of the sculpted ear
PROSIO_BASE_EAR_RADII :: Vec3{0.163, 0.289, 0.070}
// resting fold angle, forward pitch and height over which the ears ease into the jump response
PROSIO_BASE_EAR_FOLD :: Vec3{2.49, 0.31, 0.23}
// distance from ear hinge to center of the flap
PROSIO_BASE_EAR_CENTER :: f32(0.245)
// jump fold, sensitivity to vertical velocity and minimum fold angle
PROSIO_BASE_EAR_AIR :: Vec3{1.75, 0.13, 0.84}
// placement of the rounded snout
PROSIO_BASE_SNOUT_CENTER :: Vec3{0, -0.082, 0.437}
// radii of the recessed nose plate
PROSIO_BASE_SNOUT_RADII :: Vec3{0.219, 0.128, 0.147}
// brow anchor in the head frame
PROSIO_BASE_BROW_ANCHOR :: Vec3{0.178, 0.210, 0.359}
// skin ridge dimensions
PROSIO_BASE_BROW_RADII :: Vec3{0.127, 0.042, 0.054}
// lift, retreat along the forehead and tilt per unit of expression
PROSIO_BASE_BROW_MOTION :: Vec3{0.044, 0.026, 0.43}
// curve around the forehead, resting arch and contribution of emotional tilt to lift
PROSIO_BASE_BROW_TURN :: Vec3{0.28, 0.05, 0.70}
// reference mass in kg and mass range over which the pec definition softens
PROSIO_BASE_PEC_MASS :: Vec2{70, 48}
// relative horizontal, vertical and depth placement on the chest
PROSIO_BASE_PEC_ANCHOR :: Vec3{0.45, 0.48, 0.65}
// width share of the chest, half-height and frontal thickness
PROSIO_BASE_PEC_RADII :: Vec3{0.57, 0.16, 0.132}
// relative vertical softening, depth softening and extra training definition
PROSIO_BASE_PEC_MOTION :: Vec3{0.30, 0.22, 0.19}
// palm width and depth relative to arm radius, and its constant half-height
PROSIO_BASE_HAND_RADII :: Vec3{1.07, 0.083, 0.93}
// center of the eye in the head frame
PROSIO_BASE_EYE_ANCHOR :: Vec3{0.175, 0.070, 0.393}
// width, height and depth of the glossy black eye
PROSIO_BASE_EYE_RADII :: Vec3{0.080, 0.109, 0.057}
// eye yaw on the head
PROSIO_BASE_EYE_TURN :: f32(0.27)
// closed eyelid position in the eye frame
PROSIO_BASE_LID_AT :: Vec3{0, -0.003, 0.024}
// closed eyelid shape
PROSIO_BASE_LID_RADII :: Vec3{0.088, 0.013, 0.028}
// placement of the main catchlight
PROSIO_BASE_GLINT_AT :: Vec3{-0.024, 0.044, 0.045}
// main catchlight dimensions
PROSIO_BASE_GLINT_RADII :: Vec3{0.029, 0.035, 0.016}
// placement of the small catchlight
PROSIO_BASE_SMALL_GLINT_AT :: Vec3{0.025, -0.040, 0.048}
// small catchlight dimensions
PROSIO_BASE_SMALL_GLINT_RADII :: Vec3{0.014, 0.014, 0.009}
// half-width, center height and depth of the smile
PROSIO_BASE_MOUTH :: Vec3{0.143, -0.242, 0.388}
// resting rise, expressive lift, and depth adjustment at the mouth corners
PROSIO_BASE_SMILE_ARC :: Vec3{0.032, 0.020, 0.018}
// resting and expressive smile segment angles
PROSIO_BASE_SMILE_TILT :: Vec2{0.36, 0.20}
// dimensions of each stroke segment
PROSIO_BASE_SMILE_RADII :: Vec3{0.035, 0.006, 0.014}
// shape of the mouth when open
PROSIO_BASE_OPEN_MOUTH :: Vec3{0.062, 0.033, 0.025}
// shape of gritted teeth
PROSIO_BASE_TEETH :: Vec3{0.075, 0.014, 0.022}

