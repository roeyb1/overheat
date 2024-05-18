//
// This file was auto-generated using the following command:
//
// jai generate.jai - -compile
//

Col :: enum s32 {
    NodeBackground                :: 0;
    NodeBackgroundHovered         :: 1;
    NodeBackgroundSelected        :: 2;
    NodeOutline                   :: 3;
    TitleBar                      :: 4;
    TitleBarHovered               :: 5;
    TitleBarSelected              :: 6;
    Link                          :: 7;
    LinkHovered                   :: 8;
    LinkSelected                  :: 9;
    Pin                           :: 10;
    PinHovered                    :: 11;
    BoxSelector                   :: 12;
    BoxSelectorOutline            :: 13;
    GridBackground                :: 14;
    GridLine                      :: 15;
    MiniMapBackground             :: 16;
    MiniMapBackgroundHovered      :: 17;
    MiniMapOutline                :: 18;
    MiniMapOutlineHovered         :: 19;
    MiniMapNodeBackground         :: 20;
    MiniMapNodeBackgroundHovered  :: 21;
    MiniMapNodeBackgroundSelected :: 22;
    MiniMapNodeOutline            :: 23;
    MiniMapLink                   :: 24;
    MiniMapLinkSelected           :: 25;
    MiniMapCanvas                 :: 26;
    MiniMapCanvasOutline          :: 27;
    COUNT                         :: 28;

    ImNodesCol_NodeBackground                :: NodeBackground;
    ImNodesCol_NodeBackgroundHovered         :: NodeBackgroundHovered;
    ImNodesCol_NodeBackgroundSelected        :: NodeBackgroundSelected;
    ImNodesCol_NodeOutline                   :: NodeOutline;
    ImNodesCol_TitleBar                      :: TitleBar;
    ImNodesCol_TitleBarHovered               :: TitleBarHovered;
    ImNodesCol_TitleBarSelected              :: TitleBarSelected;
    ImNodesCol_Link                          :: Link;
    ImNodesCol_LinkHovered                   :: LinkHovered;
    ImNodesCol_LinkSelected                  :: LinkSelected;
    ImNodesCol_Pin                           :: Pin;
    ImNodesCol_PinHovered                    :: PinHovered;
    ImNodesCol_BoxSelector                   :: BoxSelector;
    ImNodesCol_BoxSelectorOutline            :: BoxSelectorOutline;
    ImNodesCol_GridBackground                :: GridBackground;
    ImNodesCol_GridLine                      :: GridLine;
    ImNodesCol_MiniMapBackground             :: MiniMapBackground;
    ImNodesCol_MiniMapBackgroundHovered      :: MiniMapBackgroundHovered;
    ImNodesCol_MiniMapOutline                :: MiniMapOutline;
    ImNodesCol_MiniMapOutlineHovered         :: MiniMapOutlineHovered;
    ImNodesCol_MiniMapNodeBackground         :: MiniMapNodeBackground;
    ImNodesCol_MiniMapNodeBackgroundHovered  :: MiniMapNodeBackgroundHovered;
    ImNodesCol_MiniMapNodeBackgroundSelected :: MiniMapNodeBackgroundSelected;
    ImNodesCol_MiniMapNodeOutline            :: MiniMapNodeOutline;
    ImNodesCol_MiniMapLink                   :: MiniMapLink;
    ImNodesCol_MiniMapLinkSelected           :: MiniMapLinkSelected;
    ImNodesCol_MiniMapCanvas                 :: MiniMapCanvas;
    ImNodesCol_MiniMapCanvasOutline          :: MiniMapCanvasOutline;
    ImNodesCol_COUNT                         :: COUNT;
}

StyleVar :: enum s32 {
    GridSpacing               :: 0;
    NodeCornerRounding        :: 1;
    NodePadding               :: 2;
    NodeBorderThickness       :: 3;
    LinkThickness             :: 4;
    LinkLineSegmentsPerLength :: 5;
    LinkHoverDistance         :: 6;
    PinCircleRadius           :: 7;
    PinQuadSideLength         :: 8;
    PinTriangleSideLength     :: 9;
    PinLineThickness          :: 10;
    PinHoverRadius            :: 11;
    PinOffset                 :: 12;
    MiniMapPadding            :: 13;
    MiniMapOffset             :: 14;
    COUNT                     :: 15;

    ImNodesStyleVar_GridSpacing               :: GridSpacing;
    ImNodesStyleVar_NodeCornerRounding        :: NodeCornerRounding;
    ImNodesStyleVar_NodePadding               :: NodePadding;
    ImNodesStyleVar_NodeBorderThickness       :: NodeBorderThickness;
    ImNodesStyleVar_LinkThickness             :: LinkThickness;
    ImNodesStyleVar_LinkLineSegmentsPerLength :: LinkLineSegmentsPerLength;
    ImNodesStyleVar_LinkHoverDistance         :: LinkHoverDistance;
    ImNodesStyleVar_PinCircleRadius           :: PinCircleRadius;
    ImNodesStyleVar_PinQuadSideLength         :: PinQuadSideLength;
    ImNodesStyleVar_PinTriangleSideLength     :: PinTriangleSideLength;
    ImNodesStyleVar_PinLineThickness          :: PinLineThickness;
    ImNodesStyleVar_PinHoverRadius            :: PinHoverRadius;
    ImNodesStyleVar_PinOffset                 :: PinOffset;
    ImNodesStyleVar_MiniMapPadding            :: MiniMapPadding;
    ImNodesStyleVar_MiniMapOffset             :: MiniMapOffset;
    ImNodesStyleVar_COUNT                     :: COUNT;
}

StyleFlags :: enum_flags s32 {
    None        :: 0x0;
    NodeOutline :: 0x1;
    GridLines   :: 0x4;

    ImNodesStyleFlags_None        :: None;
    ImNodesStyleFlags_NodeOutline :: NodeOutline;
    ImNodesStyleFlags_GridLines   :: GridLines;
}

PinShape :: enum s32 {
    Circle         :: 0;
    CircleFilled   :: 1;
    Triangle       :: 2;
    TriangleFilled :: 3;
    Quad           :: 4;
    QuadFilled     :: 5;

    ImNodesPinShape_Circle         :: Circle;
    ImNodesPinShape_CircleFilled   :: CircleFilled;
    ImNodesPinShape_Triangle       :: Triangle;
    ImNodesPinShape_TriangleFilled :: TriangleFilled;
    ImNodesPinShape_Quad           :: Quad;
    ImNodesPinShape_QuadFilled     :: QuadFilled;
}

// This enum controls the way the attribute pins behave.
AttributeFlags :: enum_flags s32 {
    None                          :: 0x0;

    EnableLinkDetachWithDragClick :: 0x1;

    EnableLinkCreationOnSnap      :: 0x2;

    ImNodesAttributeFlags_None                          :: None;

    ImNodesAttributeFlags_EnableLinkDetachWithDragClick :: EnableLinkDetachWithDragClick;

    ImNodesAttributeFlags_EnableLinkCreationOnSnap      :: EnableLinkCreationOnSnap;
}

IO :: struct {
    EmulateThreeButtonMouse :: struct {
        // The keyboard modifier to use in combination with mouse left click to pan the editor view.
        // Set to NULL by default. To enable this feature, set the modifier to point to a boolean
        // indicating the state of a modifier. For example,
        //
        // ImNodes::GetIO().EmulateThreeButtonMouse.Modifier = &ImGui::GetIO().KeyAlt;
        Modifier: *bool;
    }

    EmulateThreeButtonMouse_:     EmulateThreeButtonMouse;

    LinkDetachWithModifierClick :: struct {
        // Pointer to a boolean value indicating when the desired modifier is pressed. Set to NULL
        // by default. To enable the feature, set the modifier to point to a boolean indicating the
        // state of a modifier. For example,
        //
        // ImNodes::GetIO().LinkDetachWithModifierClick.Modifier = &ImGui::GetIO().KeyCtrl;
        //
        // Left-clicking a link with this modifier pressed will detach that link. NOTE: the user has
        // to actually delete the link for this to work. A deleted link can be detected by calling
        // IsLinkDestroyed() after EndNodeEditor().
        Modifier: *bool;
    }

    LinkDetachWithModifierClick_: LinkDetachWithModifierClick;

    // Holding alt mouse button pans the node area, by default middle mouse button will be used
    // Set based on ImGuiMouseButton values
    AltMouseButton:               s32;

    // Panning speed when dragging an element and mouse is outside the main editor view.
    AutoPanningSpeed:             float;
}

Style :: struct {
    GridSpacing:               float;

    NodeCornerRounding:        float;
    NodePadding:               ImVec2;
    NodeBorderThickness:       float;

    LinkThickness:             float;
    LinkLineSegmentsPerLength: float;
    LinkHoverDistance:         float;

    // The circle radius used when the pin shape is either ImNodesPinShape_Circle or
    // ImNodesPinShape_CircleFilled.
    PinCircleRadius:           float;

    // The quad side length used when the shape is either ImNodesPinShape_Quad or
    // ImNodesPinShape_QuadFilled.
    PinQuadSideLength:         float;

    // The equilateral triangle side length used when the pin shape is either
    // ImNodesPinShape_Triangle or ImNodesPinShape_TriangleFilled.
    PinTriangleSideLength:     float;

    // The thickness of the line used when the pin shape is not filled.
    PinLineThickness:          float;

    // The radius from the pin's center position inside of which it is detected as being hovered
    // over.
    PinHoverRadius:            float;

    // Offsets the pins' positions from the edge of the node to the outside of the node.
    PinOffset:                 float;

    // Mini-map padding size between mini-map edge and mini-map content.
    MiniMapPadding:            ImVec2;
    // Mini-map offset from the screen side.
    MiniMapOffset:             ImVec2;

    // By default, ImNodesStyleFlags_NodeOutline and ImNodesStyleFlags_Gridlines are enabled.
    Flags:                     StyleFlags;

    // Set these mid-frame using Push/PopColorStyle. You can index this color array with with a
    // ImNodesCol value.
    Colors:                    [28] u32;
}

MiniMapLocation :: enum s32 {
    BottomLeft  :: 0;
    BottomRight :: 1;
    TopLeft     :: 2;
    TopRight    :: 3;

    ImNodesMiniMapLocation_BottomLeft  :: BottomLeft;
    ImNodesMiniMapLocation_BottomRight :: BottomRight;
    ImNodesMiniMapLocation_TopLeft     :: TopLeft;
    ImNodesMiniMapLocation_TopRight    :: TopRight;
}

ImNodesContext :: struct {}

// An editor context corresponds to a set of nodes in a single workspace (created with a single
// Begin/EndNodeEditor pair)
//
// By default, the library creates an editor context behind the scenes, so using any of the imnodes
// functions doesn't require you to explicitly create a context.
EditorContext :: struct {}

MiniMapNodeHoveringCallback :: #type (unknown0: s32, unknown1: *void) -> void #c_call;

MiniMapNodeHoveringCallbackUserData :: *void;

// Call this function if you are compiling imnodes in to a dll, separate from ImGui. Calling this
// function sets the GImGui global variable, which is not shared across dll boundaries.
SetImGuiContext :: (ctx: *ImGuiContext) -> void #foreign imnodes "?SetImGuiContext@ImNodes@@YAXPEAUImGuiContext@@@Z";

CreateContext :: () -> *ImNodesContext #foreign imnodes "?CreateContext@ImNodes@@YAPEAUImNodesContext@@XZ";
DestroyContext :: (ctx: *ImNodesContext = null) -> void #foreign imnodes "?DestroyContext@ImNodes@@YAXPEAUImNodesContext@@@Z";
GetCurrentContext :: () -> *ImNodesContext #foreign imnodes "?GetCurrentContext@ImNodes@@YAPEAUImNodesContext@@XZ";
SetCurrentContext :: (ctx: *ImNodesContext) -> void #foreign imnodes "?SetCurrentContext@ImNodes@@YAXPEAUImNodesContext@@@Z";

EditorContextCreate :: () -> *EditorContext #foreign imnodes "?EditorContextCreate@ImNodes@@YAPEAUImNodesEditorContext@@XZ";
EditorContextFree :: (unknown0: *EditorContext) -> void #foreign imnodes "?EditorContextFree@ImNodes@@YAXPEAUImNodesEditorContext@@@Z";
EditorContextSet :: (unknown0: *EditorContext) -> void #foreign imnodes "?EditorContextSet@ImNodes@@YAXPEAUImNodesEditorContext@@@Z";
EditorContextGetPanning :: () -> ImVec2 #cpp_return_type_is_non_pod #foreign imnodes "?EditorContextGetPanning@ImNodes@@YA?AUImVec2@@XZ";
EditorContextResetPanning :: (pos: *ImVec2) -> void #foreign imnodes "?EditorContextResetPanning@ImNodes@@YAXAEBUImVec2@@@Z";
EditorContextResetPanning :: (pos: ImVec2) #no_context {
    EditorContextResetPanning(*pos);
}
EditorContextMoveToNode :: (node_id: s32) -> void #foreign imnodes "?EditorContextMoveToNode@ImNodes@@YAXH@Z";

GetIO :: () -> *IO #foreign imnodes "?GetIO@ImNodes@@YAAEAUImNodesIO@@XZ";

// Returns the global style struct. See the struct declaration for default values.
GetStyle :: () -> *Style #foreign imnodes "?GetStyle@ImNodes@@YAAEAUImNodesStyle@@XZ";

// Style presets matching the dear imgui styles of the same name.
StyleColorsDark :: () -> void #foreign imnodes "?StyleColorsDark@ImNodes@@YAXXZ";
StyleColorsClassic :: () -> void #foreign imnodes "?StyleColorsClassic@ImNodes@@YAXXZ";
StyleColorsLight :: () -> void #foreign imnodes "?StyleColorsLight@ImNodes@@YAXXZ";

// The top-level function call. Call this before calling BeginNode/EndNode. Calling this function
// will result the node editor grid workspace being rendered.
BeginNodeEditor :: () -> void #foreign imnodes "?BeginNodeEditor@ImNodes@@YAXXZ";
EndNodeEditor :: () -> void #foreign imnodes "?EndNodeEditor@ImNodes@@YAXXZ";

// Add a navigable minimap to the editor; call before EndNodeEditor after all
// nodes and links have been specified
//MiniMap :: (minimap_size_fraction: float = 0.2, location: MiniMapLocation = .TopLeft, node_hovering_callback: MiniMapNodeHoveringCallback = null, node_hovering_callback_data: MiniMapNodeHoveringCallbackUserData = null) -> void #foreign imnodes "?MiniMap@ImNodes@@YAXMHQ6AXHPEAX@ZQEAX@Z";

// Use PushColorStyle and PopColorStyle to modify ImNodesStyle::Colors mid-frame.
PushColorStyle :: (item: Col, color: u32) -> void #foreign imnodes "?PushColorStyle@ImNodes@@YAXHI@Z";
PopColorStyle :: () -> void #foreign imnodes "?PopColorStyle@ImNodes@@YAXXZ";
PushStyleVar :: (style_item: StyleVar, value: float) -> void #foreign imnodes "?PushStyleVar@ImNodes@@YAXHM@Z";
PushStyleVar :: (style_item: StyleVar, value: *ImVec2) -> void #foreign imnodes "?PushStyleVar@ImNodes@@YAXHAEBUImVec2@@@Z";
PushStyleVar :: (style_item: StyleVar, value: ImVec2) #no_context {
    PushStyleVar(style_item, *value);
}
PopStyleVar :: (count: s32 = 1) -> void #foreign imnodes "?PopStyleVar@ImNodes@@YAXH@Z";

// id can be any positive or negative integer, but INT_MIN is currently reserved for internal use.
BeginNode :: (id: s32) -> void #foreign imnodes "?BeginNode@ImNodes@@YAXH@Z";
EndNode :: () -> void #foreign imnodes "?EndNode@ImNodes@@YAXXZ";

GetNodeDimensions :: (id: s32) -> ImVec2 #cpp_return_type_is_non_pod #foreign imnodes "?GetNodeDimensions@ImNodes@@YA?AUImVec2@@H@Z";

// Place your node title bar content (such as the node title, using ImGui::Text) between the
// following function calls. These functions have to be called before adding any attributes, or the
// layout of the node will be incorrect.
BeginNodeTitleBar :: () -> void #foreign imnodes "?BeginNodeTitleBar@ImNodes@@YAXXZ";
EndNodeTitleBar :: () -> void #foreign imnodes "?EndNodeTitleBar@ImNodes@@YAXXZ";

// Create an input attribute block. The pin is rendered on left side.
BeginInputAttribute :: (id: s32, shape: PinShape = .CircleFilled) -> void #foreign imnodes "?BeginInputAttribute@ImNodes@@YAXHH@Z";
EndInputAttribute :: () -> void #foreign imnodes "?EndInputAttribute@ImNodes@@YAXXZ";

// Create an output attribute block. The pin is rendered on the right side.
BeginOutputAttribute :: (id: s32, shape: PinShape = .CircleFilled) -> void #foreign imnodes "?BeginOutputAttribute@ImNodes@@YAXHH@Z";
EndOutputAttribute :: () -> void #foreign imnodes "?EndOutputAttribute@ImNodes@@YAXXZ";

// Create a static attribute block. A static attribute has no pin, and therefore can't be linked to
// anything. However, you can still use IsAttributeActive() and IsAnyAttributeActive() to check for
// attribute activity.
BeginStaticAttribute :: (id: s32) -> void #foreign imnodes "?BeginStaticAttribute@ImNodes@@YAXH@Z";
EndStaticAttribute :: () -> void #foreign imnodes "?EndStaticAttribute@ImNodes@@YAXXZ";

// Push a single AttributeFlags value. By default, only AttributeFlags_None is set.
PushAttributeFlag :: (flag: AttributeFlags) -> void #foreign imnodes "?PushAttributeFlag@ImNodes@@YAXH@Z";
PopAttributeFlag :: () -> void #foreign imnodes "?PopAttributeFlag@ImNodes@@YAXXZ";

// Render a link between attributes.
// The attributes ids used here must match the ids used in Begin(Input|Output)Attribute function
// calls. The order of start_attr and end_attr doesn't make a difference for rendering the link.
Link :: (id: s32, start_attribute_id: s32, end_attribute_id: s32) -> void #foreign imnodes "?Link@ImNodes@@YAXHHH@Z";

// Enable or disable the ability to click and drag a specific node.
SetNodeDraggable :: (node_id: s32, draggable: bool) -> void #foreign imnodes "?SetNodeDraggable@ImNodes@@YAXH_N@Z";

// Use the following functions to get and set the node's coordinates in these coordinate systems.
SetNodeScreenSpacePos :: (node_id: s32, screen_space_pos: *ImVec2) -> void #foreign imnodes "?SetNodeScreenSpacePos@ImNodes@@YAXHAEBUImVec2@@@Z";
SetNodeScreenSpacePos :: (node_id: s32, screen_space_pos: ImVec2) #no_context {
    SetNodeScreenSpacePos(node_id, *screen_space_pos);
}
SetNodeEditorSpacePos :: (node_id: s32, editor_space_pos: *ImVec2) -> void #foreign imnodes "?SetNodeEditorSpacePos@ImNodes@@YAXHAEBUImVec2@@@Z";
SetNodeEditorSpacePos :: (node_id: s32, editor_space_pos: ImVec2) #no_context {
    SetNodeEditorSpacePos(node_id, *editor_space_pos);
}
SetNodeGridSpacePos :: (node_id: s32, grid_pos: *ImVec2) -> void #foreign imnodes "?SetNodeGridSpacePos@ImNodes@@YAXHAEBUImVec2@@@Z";
SetNodeGridSpacePos :: (node_id: s32, grid_pos: ImVec2) #no_context {
    SetNodeGridSpacePos(node_id, *grid_pos);
}

GetNodeScreenSpacePos :: (node_id: s32) -> ImVec2 #cpp_return_type_is_non_pod #foreign imnodes "?GetNodeScreenSpacePos@ImNodes@@YA?AUImVec2@@H@Z";
GetNodeEditorSpacePos :: (node_id: s32) -> ImVec2 #cpp_return_type_is_non_pod #foreign imnodes "?GetNodeEditorSpacePos@ImNodes@@YA?AUImVec2@@H@Z";
GetNodeGridSpacePos :: (node_id: s32) -> ImVec2 #cpp_return_type_is_non_pod #foreign imnodes "?GetNodeGridSpacePos@ImNodes@@YA?AUImVec2@@H@Z";

// Returns true if the current node editor canvas is being hovered over by the mouse, and is not
// blocked by any other windows.
IsEditorHovered :: () -> bool #foreign imnodes "?IsEditorHovered@ImNodes@@YA_NXZ";

// The following functions return true if a UI element is being hovered over by the mouse cursor.
// Assigns the id of the UI element being hovered over to the function argument. Use these functions
// after EndNodeEditor() has been called.
IsNodeHovered :: (node_id: *s32) -> bool #foreign imnodes "?IsNodeHovered@ImNodes@@YA_NPEAH@Z";
IsLinkHovered :: (link_id: *s32) -> bool #foreign imnodes "?IsLinkHovered@ImNodes@@YA_NPEAH@Z";
IsPinHovered :: (attribute_id: *s32) -> bool #foreign imnodes "?IsPinHovered@ImNodes@@YA_NPEAH@Z";

// Use The following two functions to query the number of selected nodes or links in the current
// editor. Use after calling EndNodeEditor().
NumSelectedNodes :: () -> s32 #foreign imnodes "?NumSelectedNodes@ImNodes@@YAHXZ";
NumSelectedLinks :: () -> s32 #foreign imnodes "?NumSelectedLinks@ImNodes@@YAHXZ";

// Get the selected node/link ids. The pointer argument should point to an integer array with at
// least as many elements as the respective NumSelectedNodes/NumSelectedLinks function call
// returned.
GetSelectedNodes :: (node_ids: *s32) -> void #foreign imnodes "?GetSelectedNodes@ImNodes@@YAXPEAH@Z";
GetSelectedLinks :: (link_ids: *s32) -> void #foreign imnodes "?GetSelectedLinks@ImNodes@@YAXPEAH@Z";

// Clears the list of selected nodes/links. Useful if you want to delete a selected node or link.
ClearNodeSelection :: () -> void #foreign imnodes "?ClearNodeSelection@ImNodes@@YAXXZ";
ClearLinkSelection :: () -> void #foreign imnodes "?ClearLinkSelection@ImNodes@@YAXXZ";

// Use the following functions to add or remove individual nodes or links from the current editors
// selection. Note that all functions require the id to be an existing valid id for this editor.
// Select-functions has the precondition that the object is currently considered unselected.
// Clear-functions has the precondition that the object is currently considered selected.
// Preconditions listed above can be checked via IsNodeSelected/IsLinkSelected if not already
// known.
SelectNode :: (node_id: s32) -> void #foreign imnodes "?SelectNode@ImNodes@@YAXH@Z";
ClearNodeSelection :: (node_id: s32) -> void #foreign imnodes "?ClearNodeSelection@ImNodes@@YAXH@Z";
IsNodeSelected :: (node_id: s32) -> bool #foreign imnodes "?IsNodeSelected@ImNodes@@YA_NH@Z";
SelectLink :: (link_id: s32) -> void #foreign imnodes "?SelectLink@ImNodes@@YAXH@Z";
ClearLinkSelection :: (link_id: s32) -> void #foreign imnodes "?ClearLinkSelection@ImNodes@@YAXH@Z";
IsLinkSelected :: (link_id: s32) -> bool #foreign imnodes "?IsLinkSelected@ImNodes@@YA_NH@Z";

// Was the previous attribute active? This will continuously return true while the left mouse button
// is being pressed over the UI content of the attribute.
IsAttributeActive :: () -> bool #foreign imnodes "?IsAttributeActive@ImNodes@@YA_NXZ";

// Was any attribute active? If so, sets the active attribute id to the output function argument.
IsAnyAttributeActive :: (attribute_id: *s32 = null) -> bool #foreign imnodes "?IsAnyAttributeActive@ImNodes@@YA_NPEAH@Z";

// Did the user start dragging a new link from a pin?
IsLinkStarted :: (started_at_attribute_id: *s32) -> bool #foreign imnodes "?IsLinkStarted@ImNodes@@YA_NPEAH@Z";

// Did the user drop the dragged link before attaching it to a pin?
// There are two different kinds of situations to consider when handling this event:
// 1) a link which is created at a pin and then dropped
// 2) an existing link which is detached from a pin and then dropped
// Use the including_detached_links flag to control whether this function triggers when the user
// detaches a link and drops it.
IsLinkDropped :: (started_at_attribute_id: *s32 = null, including_detached_links := true) -> bool #foreign imnodes "?IsLinkDropped@ImNodes@@YA_NPEAH_N@Z";

// Did the user finish creating a new link?
IsLinkCreated :: (started_at_attribute_id: *s32, ended_at_attribute_id: *s32, created_from_snap: *bool = null) -> bool #foreign imnodes "?IsLinkCreated@ImNodes@@YA_NPEAH0PEA_N@Z";

IsLinkCreated :: (started_at_node_id: *s32, started_at_attribute_id: *s32, ended_at_node_id: *s32, ended_at_attribute_id: *s32, created_from_snap: *bool = null) -> bool #foreign imnodes "?IsLinkCreated@ImNodes@@YA_NPEAH000PEA_N@Z";

// Was an existing link detached from a pin by the user? The detached link's id is assigned to the
// output argument link_id.
IsLinkDestroyed :: (link_id: *s32) -> bool #foreign imnodes "?IsLinkDestroyed@ImNodes@@YA_NPEAH@Z";

// Use the following functions to write the editor context's state to a string, or directly to a
// file. The editor context is serialized in the INI file format.
SaveCurrentEditorStateToIniString :: (data_size: *u64 = null) -> *u8 #foreign imnodes "?SaveCurrentEditorStateToIniString@ImNodes@@YAPEBDPEA_K@Z";
SaveEditorStateToIniString :: (editor: *EditorContext, data_size: *u64 = null) -> *u8 #foreign imnodes "?SaveEditorStateToIniString@ImNodes@@YAPEBDPEBUImNodesEditorContext@@PEA_K@Z";

LoadCurrentEditorStateFromIniString :: (data: *u8, data_size: u64) -> void #foreign imnodes "?LoadCurrentEditorStateFromIniString@ImNodes@@YAXPEBD_K@Z";
LoadEditorStateFromIniString :: (editor: *EditorContext, data: *u8, data_size: u64) -> void #foreign imnodes "?LoadEditorStateFromIniString@ImNodes@@YAXPEAUImNodesEditorContext@@PEBD_K@Z";

SaveCurrentEditorStateToIniFile :: (file_name: *u8) -> void #foreign imnodes "?SaveCurrentEditorStateToIniFile@ImNodes@@YAXPEBD@Z";
SaveEditorStateToIniFile :: (editor: *EditorContext, file_name: *u8) -> void #foreign imnodes "?SaveEditorStateToIniFile@ImNodes@@YAXPEBUImNodesEditorContext@@PEBD@Z";

LoadCurrentEditorStateFromIniFile :: (file_name: *u8) -> void #foreign imnodes "?LoadCurrentEditorStateFromIniFile@ImNodes@@YAXPEBD@Z";
LoadEditorStateFromIniFile :: (editor: *EditorContext, file_name: *u8) -> void #foreign imnodes "?LoadEditorStateFromIniFile@ImNodes@@YAXPEAUImNodesEditorContext@@PEBD@Z";

#scope_file

#import "Basic"; // For push_context

imnodes :: #library "win/ImNodes";
