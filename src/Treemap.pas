{*******************************************************}
{                                                       }
{       Squarified Treemap Component                    }
{                                                       }
{       Copyright (c) 2026 Rezar Behzad & Ingo Jache    }
{       All rights reserved.                            }
{                                                       }
{       https://www.fe1.com/treemap/                    }
{       https://github.com/ijache/treemap               }
{                                                       }
{*******************************************************}
/// @abstract(Squarified treemap component for the VCL.)
///
/// This unit implements @link(TTreeMap), a @code(TGraphicControl) descendant
/// that renders a set of weighted items as a @italic(squarified) treemap:
/// nested rectangles whose areas are proportional to each item's
/// @link(TTreeMapItem.Size) and whose aspect ratios are kept as close to
/// square as possible for readability.
///
/// The public model consists of three cooperating types:
/// @unorderedList(
///   @item(@link(TTreeMapItem) -- a single node, carrying a size/weight,
///     caption, colors and an optional list of child nodes.)
///   @item(@link(TTreeMapContainer) -- an owning, size-sorted list of items;
///     the control's @link(TTreeMap.Items) property is such a container.)
///   @item(@link(TTreeMap) -- the visual control that lays the items out,
///     paints them and tracks hovering, selection and clicks.)
/// )
///
/// Custom rendering is possible through @link(TTreeMap.OnDrawItem); when no
/// handler is assigned an internal default painter is used.
///
/// @author Rezar Behzad & Ingo Jache
/// @created 26.07.2026
/// @lastmod 26.07.2026
unit Treemap;

interface

uses
  Windows,Classes,SysUtils,Types,Graphics,Controls,ImgList,Math,Messages,DateUtils;

type
  TTreeMapItem = class;
  TTreeMapContainer = class;

  /// State flags describing how a @link(TTreeMapItem) is to be painted. They
  /// are passed as a set to draw handlers (@link(TOnDrawTreeMapItemEvent)) and
  /// click handlers (@link(TOnTreeMapItemClickEvent)).
  TTreeMapItemState = (
    tmisHighlight,      //< The mouse pointer is currently hovering over the item.
    tmisSelected,       //< The item is selected (see @link(TTreeMap.SetSelected)).
    tmisLast            //< Internal: marks the last item included in the current layout.
  );
  /// A set of @link(TTreeMapItemState) flags describing an item's paint state.
  TTreeMapItemStates = set of TTreeMapItemState;

  /// Custom-draw event for a single treemap item.
  ///
  /// Assign a handler to @link(TTreeMap.OnDrawItem) to take over painting of
  /// items.
  /// @param(Sender The @link(TTreeMap) control requesting the draw.)
  /// @param(Canvas The canvas to paint onto.)
  /// @param(Item The item to be drawn.)
  /// @param(State The item's current @link(TTreeMapItemStates paint state).)
  /// @param(Area The rectangle the item must be drawn into. This is a
  ///   @code(var) parameter: a handler may shrink it -- for example to a small
  ///   title bar -- and return the remaining area, into which the item's
  ///   children are then laid out and drawn.)
  TOnDrawTreeMapItemEvent = procedure(
    Sender: TObject;
    Canvas: TCanvas;
    Item: TTreeMapItem;
    State: TTreeMapItemStates;
    var Area: TRect) of object;

  /// Click and double-click event for a treemap item. Used by both
  /// @link(TTreeMap.OnClickItem) and @link(TTreeMap.OnDblClickItem).
  /// @param(Sender The @link(TTreeMap) control that raised the event.)
  /// @param(Item The item under the mouse pointer.)
  /// @param(Button The mouse button involved.)
  /// @param(State The item's current @link(TTreeMapItemStates paint state).)
  TOnTreeMapItemClickEvent = procedure(
    Sender: TObject;
    Item: TTreeMapItem;
    Button: TMouseButton;
    State: TTreeMapItemStates
  ) of object;

  /// @abstract(A control that displays weighted items as a squarified treemap.)
  ///
  /// Populate the control through its @link(TTreeMap.Items) container, then let
  /// the control lay the items out and paint them. Items that have children are
  /// drawn as nested treemaps. Hovering and selection are tracked
  /// automatically and reported through @link(TTreeMap.OnClickItem) and
  /// @link(TTreeMap.OnDblClickItem); painting can be customized through
  /// @link(TTreeMap.OnDrawItem).
  ///
  /// Wrap bulk changes to @link(TTreeMap.Items) in
  /// @link(TTreeMap.BeginUpdate)/@link(TTreeMap.EndUpdate) to avoid
  /// intermediate repaints.
  TTreeMap = class(TGraphicControl)
  private
    fBackgroundColor: TColor;
    fSelectionColor: TColor;
    fBorderSize: integer;
    fFont: TFont;
    fUpdating: boolean;

    fItems: TTreeMapContainer;
    fSurface: TBitmap;

    fMustRelayout: boolean;

    fHoverItem: TTreeMapItem;

    fLastMouseButton: TMouseButton;
    fLastMouseUp: TDateTime;

    fDefaultItemPainter: TObject;
    fOnDrawItem: TOnDrawTreeMapItemEvent;
    fOnClickItem: TOnTreeMapItemClickEvent;
    fOnDblClickItem: TOnTreeMapItemClickEvent;

    fMinArea: integer;
    fMaxItems: integer;

    fImages: TImageList;
    fLastImages: TImageList;
    fIcons: TList;

    procedure SetMaxItems(const Value: integer);
    procedure SetMinArea(const Value: integer);
    procedure SetBorderSize(const Value: integer);
    procedure SetFont(const Value: TFont);
    procedure SetSelectionColor(const Value: TColor);
  protected
    procedure UpdateHoverItem;

    function GetItemStates(aitem: TTreeMapItem): TTreeMapItemStates;

    procedure Render;
    procedure ClearSurface(acanvas: TCanvas; arect: TRect);
    function FindItemAt(x,y: integer; aitems: TTreeMapContainer; recurse: boolean): TTreeMapItem;

    procedure ItemsHaveUpdated(Sender: TObject);

    procedure Paint; override;
    procedure Resize; override;

    procedure MouseDown(Button: TMouseButton;Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X,Y: Integer); override;

    procedure DblClick; override;

    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;

    procedure UpdateIconCache;
  public
    /// Creates the control, its default painter and an empty item container.
    constructor Create(aowner: TComponent); override;
    /// Destroys the control and frees the items it owns.
    destructor Destroy; override;

    /// Recalculates the treemap layout for @code(aitems) within @code(arect).
    ///
    /// Called internally when a relayout is required, but exposed so the same
    /// layout algorithm can be applied to arbitrary containers -- for example
    /// to render a treemap onto another canvas together with
    /// @link(TTreeMap.DrawTreemap).
    /// @param(aitems The container whose items are laid out; each item's
    ///   @link(TTreeMapItem.Rect) is updated in place.)
    /// @param(arect The rectangle the items are laid out within.)
    procedure CalculateTreemap(aitems: TTreeMapContainer; arect: TRect);

    /// Draws @code(aitems) as a treemap onto @code(acanvas) within
    /// @code(arect).
    ///
    /// This is the control's main drawing routine, but it can also render a
    /// treemap onto any canvas and for containers not managed by the control.
    /// The layout is (re)calculated first if required.
    /// @param(acanvas The target canvas.)
    /// @param(arect The rectangle to draw within.)
    /// @param(aitems The container of items to draw.)
    procedure DrawTreemap(acanvas: TCanvas; arect: TRect; aitems: TTreeMapContainer);

    /// Returns the item at control coordinates @code((x, y)), searching nested
    /// children, or @nil if no item covers that point.
    /// @param(x Horizontal position in control coordinates.)
    /// @param(y Vertical position in control coordinates.)
    /// @returns(The item at the given position, or @nil.)
    function GetItemAt(x,y: integer): TTreeMapItem;

    /// Suspends repainting while @link(TTreeMap.Items) is being modified. Must
    /// be paired with a later @link(TTreeMap.EndUpdate). Useful when adding or
    /// removing many items at once.
    procedure BeginUpdate;
    /// Resumes repainting after @link(TTreeMap.BeginUpdate), forces a relayout
    /// and repaints the control.
    procedure EndUpdate;

    /// Clears the selected state of every item, including nested children, and
    /// repaints the control.
    procedure ClearSelection;

    /// Sets or clears the selected state of a single item, repainting if the
    /// state actually changed.
    /// @param(Value The item to update. Ignored when @nil.)
    /// @param(selected @true to select the item, @false to deselect it.)
    procedure SetSelected(const Value: TTreeMapItem; selected: boolean);

    /// Repaints the control immediately, re-rendering the offscreen surface.
    procedure Repaint; override;

    /// The items rendered by the control. The container may hold a flat list or
    /// a hierarchy (items with @link(TTreeMapItem.Children)). The control owns
    /// and frees the items it contains. Runtime-only and read-only, so it is
    /// not published.
    property Items: TTreeMapContainer read fItems;
  published
    /// The maximum number of items laid out within a container. Items beyond
    /// this count are ignored by the layout. Changing it forces a relayout.
    property MaxItems: integer read fMaxItems write SetMaxItems default 200;

    /// The smallest rectangle area, in square pixels, that is still laid out.
    /// Layout stops subdividing once the available area drops below this value.
    /// Changing it forces a relayout.
    property MinArea: integer read fMinArea write SetMinArea default 64*64;

    /// Color used to clear the background behind the tiles.
    property BackgroundColor: TColor read fBackgroundColor write fBackgroundColor default clBtnFace;
    /// Border color drawn around a selected tile by the default painter.
    property SelectionColor: TColor read fSelectionColor write SetSelectionColor default $FFFFFF;
    /// Tile border thickness, in pixels, used by the default painter.
    property BorderSize: integer read fBorderSize write SetBorderSize default 1;
    /// Base font used by the default painter, which derives several sizes from
    /// its name.
    property Font: TFont read fFont write SetFont;

    /// Image list whose icons can be shown on tiles via
    /// @link(TTreeMapItem.ImageIndex).
    property Images: TImageList read fImages write fImages;

    /// Handler invoked to paint each item. When unassigned, an internal default
    /// painter is used. See @link(TOnDrawTreeMapItemEvent).
    property OnDrawItem: TOnDrawTreeMapItemEvent read fOnDrawItem write fOnDrawItem;
    /// Handler invoked on a single click on an item.
    /// See @link(TOnTreeMapItemClickEvent).
    property OnClickItem: TOnTreeMapItemClickEvent read fOnClickItem write fOnClickItem;
    /// Handler invoked on a double click on an item.
    /// See @link(TOnTreeMapItemClickEvent).
    property OnDblClickItem: TOnTreeMapItemClickEvent read fOnDblClickItem write fOnDblClickItem;
  end;



  /// @abstract(An owning, size-sorted list of @link(TTreeMapItem) instances.)
  ///
  /// @link(TTreeMapContainer.Add), @link(TTreeMapContainer.Remove),
  /// @link(TTreeMapContainer.RemoveAt) and @link(TTreeMapContainer.Clear) keep
  /// the list sorted by @link(TTreeMapItem.Size) in descending order and keep
  /// @link(TTreeMapContainer.TotalSize) up to date on every mutation. The
  /// container @bold(owns) its items: an item is freed as soon as it is
  /// removed, and when the container is cleared or destroyed.
  ///
  /// For bulk population use @link(TTreeMapContainer.FastAdd) -- which skips
  /// the duplicate check and does not preserve order -- followed by a single
  /// @link(TTreeMapContainer.Sort).
  TTreeMapContainer = class
  private
    fItems: TList;
    fTotalSize: int64;
    fOnUpdate: TNotifyEvent;

    fLayoutRect: TRect;
    fLayoutMinArea: integer;
    fLayoutMaxItems: integer;
    procedure FireOnUpdate;
    function GetCount: integer;
    function GetItem(index: integer): TTreeMapItem;
  public
    /// Creates an empty container.
    constructor Create;
    /// Clears and frees all contained items, then destroys the container.
    destructor Destroy; override;

    /// Adds a single item, preserving descending size order, and updates
    /// @link(TTreeMapContainer.TotalSize).
    /// @param(aitem The item to add; the container takes ownership of it.)
    /// @returns(The index at which the item was inserted. If the item is
    ///   already present, its existing index is returned; returns @code(-1)
    ///   when @code(aitem) is @nil.)
    function Add(aitem: TTreeMapItem): integer;

    /// Removes and frees an item, located by reference, and updates
    /// @link(TTreeMapContainer.TotalSize).
    /// @param(aitem The item to remove.)
    /// @returns(@true if the item was found and removed, @false otherwise.)
    function Remove(aitem: TTreeMapItem): boolean;

    /// Removes and frees the item at the given index and updates
    /// @link(TTreeMapContainer.TotalSize).
    /// @param(index Zero-based index of the item to remove.)
    /// @returns(@true if removed, @false if @code(index) was out of range.)
    function RemoveAt(index: integer): boolean;

    /// Returns the index of an item, located by reference.
    /// @param(aitem The item to look up.)
    /// @returns(The zero-based index, or @code(-1) if not present.)
    function IndexOf(aitem: TTreeMapItem): integer;

    /// Returns the index of the first item whose @link(TTreeMapItem.Data)
    /// pointer equals @code(adata).
    /// @param(adata The data pointer to match.)
    /// @returns(The zero-based index, or @code(-1) if no item matches.)
    function IndexOfData(adata: pointer): integer;

    /// Changes the size of the item at @code(index), moving it to its new
    /// sorted position and updating @link(TTreeMapContainer.TotalSize).
    ///
    /// This is the only supported way to change an item's size, so that the
    /// list can stay sorted without a full re-sort.
    /// @param(index Zero-based index of the item to update.)
    /// @param(newsize The new size value.)
    /// @returns(@true on success, @false if @code(index) was out of range.)
    function UpdateSizeAt(index: integer; newsize: int64): boolean;

    /// Convenience wrapper around @link(TTreeMapContainer.UpdateSizeAt) that
    /// first looks the item up by reference.
    /// @param(aitem The item whose size to change.)
    /// @param(newsize The new size value.)
    /// @returns(@true on success, @false if the item was not found.)
    function UpdateSize(aitem: TTreeMapItem; newsize: int64): boolean;

    /// Removes and frees all items and resets
    /// @link(TTreeMapContainer.TotalSize) to zero.
    procedure Clear;

    /// Sorts the list by @link(TTreeMapItem.Size) in descending order. Use
    /// together with @link(TTreeMapContainer.FastAdd).
    procedure Sort;

    /// Appends an item without checking for duplicates and without preserving
    /// sort order, updating @link(TTreeMapContainer.TotalSize). Intended for
    /// bulk population; call @link(TTreeMapContainer.Sort) once all items have
    /// been added.
    /// @param(aitem The item to append; the container takes ownership of it.)
    procedure FastAdd(aitem: TTreeMapItem);


    /// The number of items currently in the container.
    property Count: integer read GetCount;

    /// Indexed, read-only access to the contained items. This is the default
    /// property, so @code(container[i]) is equivalent to
    /// @code(container.Items[i]).
    property Items[index: integer]: TTreeMapItem read GetItem; default;

    /// The sum of the @link(TTreeMapItem.Size) values of all contained items.
    property TotalSize: int64 read fTotalSize;
  end;


  /// @abstract(A single node in a treemap: a weighted, captioned rectangle.)
  ///
  /// The most important attribute is @link(TTreeMapItem.Size), the weight from
  /// which the item's area in the layout is derived. Items live inside a
  /// @link(TTreeMapContainer), which keeps them sorted by size and owns them.
  /// An item may itself own a container of child items
  /// (@link(TTreeMapItem.Children)), which are drawn as a nested treemap.
  TTreeMapItem = class
  private
    fSize: int64;
    fCaption: string;
    fInfo: string;
    fBackgroundColor: TColor;
    fForegroundColor: TColor;

    fRect: TRect;

    fChildren: TTreeMapContainer;
    fData: Pointer;
    fTag: integer;

    // internal use. if true, item will not be drawn
    fLastItem: boolean;

    fSelected: boolean;
    fImageIndex: integer;
    function GetChildren: TTreeMapContainer;
  public
    /// Creates an item.
    /// @param(asize The item's size/weight, driving its area in the layout.)
    /// @param(acaption The caption text shown on the tile.)
    /// @param(afill The tile background/fill color.)
    /// @param(atext The caption/text color.)
    /// @param(adata An optional user pointer stored in
    ///   @link(TTreeMapItem.Data).)
    constructor Create(
      asize: int64;
      acaption: string;
      afill: TColor = $203040;
      atext: TColor = $f8f8f8;
      adata: pointer = nil
    );
    /// Destroys the item and frees its child container, if any.
    destructor Destroy; override;

    /// Returns @true if the item owns at least one child item (that is, when
    /// @link(TTreeMapItem.Children) is non-empty).
    function HasChildren: boolean;

    /// The item's size/weight. Set at creation; change it through
    /// @link(TTreeMapContainer.UpdateSize) so the owning container stays
    /// sorted.
    property Size: int64 read fSize;

    /// The rectangle assigned to the item by the layouter, in the coordinate
    /// space of the surface it was laid out on. Read-only; updated during
    /// layout.
    property Rect: TRect read fRect;

    /// The caption text drawn on the tile.
    property Caption: string read fCaption write fCaption;
    /// Secondary information text drawn on the tile (for example a formatted
    /// size).
    property Info: string read fInfo write fInfo;
    /// The tile fill color.
    property BackgroundColor: TColor read fBackgroundColor write fBackgroundColor;
    /// The caption/text color.
    property ForegroundColor: TColor read fForegroundColor write fForegroundColor;

    /// An arbitrary user pointer, for linking the item to application data.
    property Data: pointer read fData write fData;

    /// An arbitrary user integer, free for application use.
    property Tag: integer read fTag write fTag;

    /// Index into the control's @link(TTreeMap.Images) list of the icon shown
    /// on the tile, or @code(-1) for none.
    property ImageIndex: integer read fImageIndex write fImageIndex;

    /// Optional child items, drawn as a nested treemap inside this item's tile.
    /// Their sizes and @link(TTreeMapContainer.TotalSize) are independent of
    /// this item's own @link(TTreeMapItem.Size) and of the
    /// @link(TTreeMapContainer.TotalSize) of the container holding this item.
    /// Reading this property creates the child container on demand.
    property Children: TTreeMapContainer read GetChildren;

    /// @true when the item is selected. Change it through
    /// @link(TTreeMap.SetSelected) or @link(TTreeMap.ClearSelection).
    property Selected: boolean read fSelected;
  end;


/// Registers @link(TTreeMap) on the "Fasko" component palette page.
procedure Register;

implementation

//------------------------------------------------------------------------------
// functions related to layouting
//------------------------------------------------------------------------------
type TLayoutOrientation = (loVertical, loHorizontal);

// Squariness returns values >= 1 based on the aspect-ratio of the rectangle
// a value of 1 is returned for a perfect square
function Squariness(r: TRect): double;
var
  w,h: integer;
begin
  if r.Width > r.Height then begin
    w:= r.Width;
    h:= r.Height;
  end else begin
    h:= r.Width;
    w:= r.Height;
  end;
  if h = 0 then exit(0);
  result:= w/h;
end;

// PickOrientation will return loVertical if the rectangles width is bigger than its height
// otherwise it will return loHorizontal
function PickOrientation(r: TRect): TLayoutOrientation;
begin
  if r.Height = 0 then exit(loVertical);
  if r.Width > r.Height then begin
    result:= loVertical;
  end else begin
    result:= loHorizontal;
  end;
end;


// LayoutSlice takes items from startIndex to endIndex and layouts their rectangles into the
// surface with respects to the orientation provided aswell as the items size. The function
// will return the worst squariness value found within the selected rectangles.
// To calculate the layout, the function requires the sum of sizes for the selected items aswell
// as the sum of sizes for all remaining items.
function LayoutSlice(
  items: TTreemapContainer;
  startIndex: integer;
  endIndex: integer;
  surface: TRect;
  sliceSize: int64;
  restSize: int64;
  orientation: TLayoutOrientation
): double;
var
  i: integer;

  item: TTreemapItem;

  sizeA: single;
  sizeB: single;

  start: single;
begin
  // calculate the required size to layout the selected items
  // for loVertical it calculates a width, otherwise it will
  // calculate a height
  // also set a starting point to place the items rectangles
  if orientation = loVertical then begin
    sizeA:= (surface.Width / restSize) * sliceSize;
    start:= surface.Top;
  end else begin
    sizeA:= (surface.Height / restSize) * sliceSize;
    start:= surface.Left;
  end;

  for i := startIndex to endIndex do begin
    item:= items[i];

    // calculate how big the rectangle is going to be
    // which is based on the fraction of the items size
    // compared to the size of the entire slice
    if orientation = loVertical then begin
      sizeB:= surface.Height * (max(1,item.Size)/sliceSize);
      item.fRect:= rect(
        surface.Left,
        trunc(start),
        trunc(surface.Left + sizeA),
        trunc(start+sizeB)
      );
    end else begin
      sizeB:= surface.Width * (max(1,item.Size)/sliceSize);
      item.fRect:= rect(
        trunc(start),
        surface.Top,
        trunc(start + sizeB),
        trunc(surface.Top + sizeA)
      );
    end;

    // update starting point for the next rectangle
    start := start + sizeB;
  end;

  // return value is the worst squariness
  result:= Max(
    Squariness(items[startIndex].fRect),
    Squariness(items[endIndex].fRect)
  );
end;

// FixCorners will adjust the rightmost and bottom corner of a rect
// which sometimes happens during layout due to rounding errors
procedure FixCorners(surface: TRect; var r: TRect);
begin
  if r.Right >= surface.Right-2 then begin
    r.Right:= surface.Right;
  end;
  if r.Bottom >= surface.Bottom-2 then begin
    r.Bottom:= surface.Bottom;
  end;
end;

// LayoutTreemap will calculate the layout for all items in the item container
procedure LayoutTreemap(
  items: TTreeMapContainer;
  surface: TRect;
  maxItems: integer;
  minArea: integer
);
var
  i: integer;

  originalSurface: TRect;

  itemSize: int64;
  sliceSize: int64;
  restSize: int64;

  startIndex,endIndex: integer;
  orientation: TLayoutOrientation;
  lastSquariness,currentSquariness: double;

  minAreaShare: double;
begin
  if items.Count = 0 then exit;
  if (surface.width*surface.height) < minArea then exit;

  maxItems:= min(maxItems,items.Count);
  if maxItems = 0 then exit;

  originalSurface:= surface;

  minAreaShare:= minArea / (surface.width*surface.height);

  // the starting point is the entire surface
  // and the sum of all items sizes
  restSize:= 0;
  for i:= 0 to maxItems-1 do begin
    itemSize:= max(1,items[i].Size);
    if restSize > 0 then begin
      if (itemSize/restsize) < minAreaShare then begin
       maxItems:= i;
        break;
      end;
    end;
    restSize:= restSize + itemSize;
  end;

  // loop over all items
  startIndex:= 0;
  endIndex:= 0;
  while startIndex < maxItems do begin

    orientation:= PickOrientation(surface);

    // add an item along the orientation until the squariness gets worse
    sliceSize:= 0;
    lastSquariness:= 0;
    for i:= startIndex to maxItems-1 do begin
      endIndex:= i;

      itemSize:= max(1,items[i].Size);

      items[i].fLastItem:= false;
      sliceSize:= sliceSize + itemSize;
      currentSquariness:= LayoutSlice(items,startIndex,endIndex,surface,sliceSize,restSize,orientation);

      // except for the first iteration: if the squariness gets worse, revert the layout operation
      // currently this is done be recalculating the previous slice of items.
      if (currentSquariness > lastSquariness) and (i <> startIndex) then begin
        sliceSize:= sliceSize - itemSize;
        endIndex:= endIndex -1;
        LayoutSlice(items,startIndex,endIndex,surface,sliceSize,restSize,orientation);
        break;
      end;

      // remember the last (best!) squariness
      lastSquariness:= currentSquariness;
    end;


    // subtract the size we have covered
    restSize:= restSize - sliceSize;

    // calculate the remaining surface
    if orientation = loVertical then begin
      surface:= rect(
        surface.Left + items[startIndex].fRect.Width,
        surface.Top,
        surface.Right,
        surface.Bottom
      );
    end else begin
      surface:= rect(
        surface.Left,
        surface.Top + items[startIndex].fRect.Height,
        surface.Right,
        surface.Bottom
      );
    end;


    // next iteration will start with the next item
    startIndex:= endIndex+1;

  end;

  // there might be one item left:
  if startIndex = maxItems-1 then begin
    items[startIndex].fLastItem:= true;
    items[startIndex].fRect:= surface;

    FixCorners(originalSurface,items[startIndex].fRect);

  end else begin
    items[startIndex-1].fLastItem:= true;
  end;

  // fix rounding errors on rightmost/bottommost corners
  for i:= 0 to startIndex-1 do begin
    FixCorners(originalSurface,items[i].fRect);
  end;

end;
//------------------------------------------------------------------------------




//------------------------------------------------------------------------------
// containter type to carry items/weights
//------------------------------------------------------------------------------
{ TTreeMapContainer }
constructor TTreeMapContainer.Create;
begin
  fOnUpdate:= nil;
  fItems:= TList.Create;
  fTotalSize:= 0;
end;

destructor TTreeMapContainer.Destroy;
begin
  Clear;
  fItems.Free;
  inherited;
end;


procedure TTreeMapContainer.FastAdd(aitem: TTreeMapItem);
begin
  self.fItems.Add(aitem);
  fTotalSize:= fTotalSize + aitem.Size;
end;


procedure TTreeMapContainer.FireOnUpdate;
begin
  if not(assigned(fOnUpdate)) then exit;
  fOnUpdate(self);
end;

function TTreeMapContainer.Add(aitem: TTreeMapItem): integer;
var
  i: integer;
  b: TTreeMapItem;
begin
  if aitem = nil then exit(-1);

  i:= IndexOf(aitem);
  if i <> -1 then exit(i);

  for i:= 0 to fItems.Count-1 do begin
    b:= TTreeMapItem(fItems[i]);
    if b.Size <= aitem.Size then begin

      fItems.Insert(i,aitem);
      fTotalSize:= fTotalSize + aitem.Size;
      FireOnUpdate;
      exit(i);

    end;

  end;

  fItems.Add(aitem);
  fTotalSize:= fTotalSize + aitem.Size;
  FireOnUpdate;

  result:= fItems.Count-1;
end;

procedure TTreeMapContainer.Clear;
var
  i: integer;
begin
  if fItems.Count = 0 then exit;

  for i:= 0 to fItems.Count-1 do begin
    TTreeMapItem(fItems[i]).Free;
  end;
  fItems.Clear;
  fTotalSize:= 0;

  FireOnUpdate;
end;


function TTreeMapContainer.GetCount: integer;
begin
  result:= fItems.Count;
end;

function TTreeMapContainer.GetItem(index: integer): TTreeMapItem;
begin
  if (index < 0) or (index >= fItems.Count) then exit(nil);
  result:= fItems[index];

end;

function TTreeMapContainer.IndexOf(aitem: TTreeMapItem): integer;
var
  i: integer;
begin
  for i:= 0 to fItems.Count-1 do begin
    if fItems[i] = aitem then exit(i);
  end;
  result:= -1;
end;

function TTreeMapContainer.IndexOfData(adata: pointer): integer;
var
  i: integer;
  a: TTreeMapItem;
begin
  for i:= 0 to fItems.Count-1 do begin
    a:= TTreeMapItem(fItems[i]);
    if a.Data = adata then exit(i);
  end;
  result:= -1;
end;

function TTreeMapContainer.Remove(aitem: TTreeMapItem): boolean;
var
  i: integer;
begin
  if aitem = nil then exit(false);

  i:= IndexOf(aitem);
  if i = -1 then exit(false);

  fItems.Delete(i);

  fTotalSize:= fTotalSize - aitem.Size;
  aitem.Free;

  FireOnUpdate;

  result:= true;
end;

function TTreeMapContainer.RemoveAt(index: integer): boolean;
var
  aitem: TTreeMapItem;
begin
  if (index < 0) or (index >= fItems.Count) then exit(false);

  aitem:= TTreeMapItem(fItems[index]);
  fItems.Delete(index);

  fTotalSize:= fTotalSize - aitem.Size;
  aitem.Free;

  FireOnUpdate;

  result:= true;
end;

function CompareTreeMapItemsBySize(a,b: TTreeMapItem): integer;
begin
  // cant return the difference between the two items because of integer over/underflow
  if a.Size > b.Size then exit(-1);
  if a.Size < b.Size then exit(1);
  exit(0);
end;

procedure TTreeMapContainer.Sort;
begin
  fItems.Sort(@CompareTreeMapItemsBySize);
end;

function TTreeMapContainer.UpdateSize(aitem: TTreeMapItem; newsize: int64): boolean;
var
  i: integer;
begin
  i:= IndexOf(aitem);
  if i = -1 then exit(false);
  result:= UpdateSizeAt(i,newsize);
end;

function TTreeMapContainer.UpdateSizeAt(index: integer; newsize: int64): boolean;
var
  aitem: TTreeMapItem;
begin
  if (index < 0) or (index >= fItems.Count) then exit(false);

  aitem:= TTreeMapItem(fItems[index]);
  if aitem.fSize = newsize then exit(true);

  fItems.Delete(index);
  fTotalSize:= fTotalSize - aitem.Size;

  aitem.fSize:= newsize;
  result:= (Add(aitem) <> -1); // fires update event
end;
//------------------------------------------------------------------------------



//------------------------------------------------------------------------------
// item type for the container
//------------------------------------------------------------------------------
{ TTreeMapItem }
constructor TTreeMapItem.Create(
      asize: int64;
      acaption: string;
      afill: TColor = $203040;
      atext: TColor = $f8f8f8;
      adata: pointer = nil
    );
begin
  fBackgroundColor:= aFill;
  fForegroundColor:= aText;
  fChildren:= nil;

  fSize:= asize;
  fCaption:= acaption;
  fData:= adata;
  fImageIndex:= -1;
end;

destructor TTreeMapItem.Destroy;
begin
  if fChildren <> nil then fChildren.Free;
  fChildren:= nil;
  inherited;
end;


function TTreeMapItem.GetChildren: TTreeMapContainer;
begin
  if fChildren = nil then begin
    fChildren:= TTreeMapContainer.Create;
  end;
  result:= fChildren;
end;

function TTreeMapItem.HasChildren: boolean;
begin
  if fChildren = nil then exit(false);
  result:= (fChildren.Count > 0);
end;
//------------------------------------------------------------------------------



//------------------------------------------------------------------------------
// internal type used as the default item painter
//------------------------------------------------------------------------------
{ TDefaultTreeMapItemPainter }
type
  TDefaultTreeMapItemPainter = class
  private
    Fontname: string;
    BorderSize: integer;
    SelectionColor: TColor;
    Fonts: array[0..4] of TFont;
    function GenerateFont(asize: integer): TFont;
  public
    constructor Create(aBorderSize: integer; aselectionColor: TColor; aFontName: string);
    destructor Destroy; override;

    procedure DrawItem(
      Sender: TObject;
      Canvas: TCanvas;
      Item: TTreeMapItem;
      State: TTreeMapItemStates;
      var Area: TRect
    );
  end;

function Brighter(c: TColor; amount: integer): TColor;
var
  r,g,b: integer;
begin
  r:= c and $0000ff;
  g:= c and $00ff00;
  b:= c and $ff0000;

  r:= r + amount;
  if r > $ff then r:= $ff;

  amount:= amount shl 8;
  g:= g + amount;
  if g > $ff00 then g:= $ff00;

  amount:= amount shl 8;
  b:= b + amount;
  if b > $ff0000 then b:= $ff0000;

  result:= r or g or b;
end;

function Darker(c: TColor; amount: integer): TColor;
var
  r,g,b: integer;
begin
  r:= c and $0000ff;
  g:= c and $00ff00;
  b:= c and $ff0000;

  r:= r - amount;
  if r > $ff then r:= $ff else if r < 0 then r:= 0;

  amount:= amount shl 8;
  g:= g - amount;
  if g > $ff00 then g:= $ff00 else if g <= $ff  then g:= 0;

  amount:= amount shl 8;
  b:= b - amount;
  if b > $ff0000 then b:= $ff0000 else if b <= $00ff00 then b:= 0;

  result:= r or g or b;
end;


constructor TDefaultTreeMapItemPainter.Create(aBorderSize: integer; aSelectionColor: TColor; aFontname: string);
begin
  BorderSize:= aBorderSize;
  FontName:= aFontname;
  SelectionColor:= aSelectionColor;
  Fonts[0]:= GenerateFont(18);
  Fonts[1]:= GenerateFont(14);
  Fonts[2]:= GenerateFont(12);
  Fonts[3]:= GenerateFont(10);
  Fonts[4]:= GenerateFont(8);
end;

destructor TDefaultTreeMapItemPainter.Destroy;
begin
  inherited;
end;

procedure TDefaultTreeMapItemPainter.DrawItem(Sender: TObject; Canvas: TCanvas;
  Item: TTreeMapItem; State: TTreeMapItemStates; var Area: TRect);
var
  rt: TRect;
  tl: integer;
  ratio: double;

  borderColor, fillColor: TColor;

  labelBuffer: array[0..1023] of char;

  actualArea: TRect;
  remainingArea: TRect;

  imagelist: TImageList;

  icon: TIcon;
begin

  // reserve space for subitems, if applicable
  actualArea:= area;
  remainingArea:= Rect(0,0,0,0);
  if Item.HasChildren and (area.Height > 48) then begin
    remainingArea:= area;
    actualArea.Bottom:= actualArea.Top+48;
    remainingArea.Top:= actualArea.Bottom;
    remainingArea.Left:= remainingArea.Left+BorderSize;
    remainingArea.Right:= remainingArea.Right-BorderSize;
    remainingArea.Bottom:= remainingArea.Bottom-BorderSize;
  end;

  // drawing background
  if tmisSelected in State then begin
    borderColor:= SelectionColor;
  end else begin
    borderColor:= Darker(item.BackgroundColor,32);
  end;

  if tmisHighlight in State then begin
    fillColor:= Brighter(item.BackgroundColor,16);
  end else begin
    fillColor:= Brighter(item.BackgroundColor,0);
  end;

  // fill the actual area
  Canvas.Brush.Color:= fillColor;
  Canvas.FillRect(rect(
    area.Left,
    area.Top,
    area.Right,
    area.Bottom
  ));

  // draw border around the entire tile
  Canvas.Brush.Color:= borderColor;
  Canvas.FillRect(rect(
    area.Left,
    area.Top,
    area.Left+BORDERSIZE,
    area.Bottom
  ));
  Canvas.FillRect(rect(
    area.Right-BORDERSIZE,
    area.Top,
    area.Right,
    area.Bottom
  ));
  Canvas.FillRect(rect(
    area.Left,
    area.Top,
    area.Right,
    area.Top+BORDERSIZE
  ));
  Canvas.FillRect(rect(
    area.Left,
    area.Bottom-BORDERSIZE,
    area.Right,
    area.Bottom
  ));


  Canvas.Brush.Style:= bsClear;
  if (area.Width > 96) and (area.Height > 96) then begin
    imagelist:= TTreeMap(Sender).Images;
    if imagelist <> nil then begin

      if imagelist <> TTreeMap(Sender).fLastImages then begin
        TTreeMap(Sender).UpdateIconCache;
      end;

      if (item.ImageIndex >= 0) and (item.imageindex < imagelist.Count) then begin
        icon:= TIcon(TTreeMap(Sender).fIcons[item.ImageIndex]);
        if icon <> nil then begin
          DrawIconEx(
            Canvas.Handle,
            area.Left + BorderSize,area.Top + BorderSize,
            TIcon(TTreeMap(sender).fIcons[item.ImageIndex]).Handle,
            ImageList.Width, ImageList.Height,
            0, 0,
            DI_NORMAL
          );
        end;
      end;
    end;
  end;


  //-------------------------------------------------------------------
  // draw label
  //-------------------------------------------------------------------
  rt.Left := actualArea.Left + BorderSize;
  rt.Top := actualArea.Top + BorderSize;
  rt.Bottom := actualArea.Bottom-BorderSize;
  rt.Right := actualArea.Right-BorderSize;

  tl:= Length(Item.Caption);
  if tl > 0 then begin

    ratio:= rt.Width / tl;

    if ratio < 10  then begin
      Canvas.Font.Assign(Fonts[4]);
    end else
    if ratio < 15  then begin
      Canvas.Font.Assign(Fonts[3]);
    end else
    if ratio < 20  then begin
      Canvas.Font.Assign(Fonts[2]);
    end else
    if ratio < 25  then begin
      Canvas.Font.Assign(Fonts[1]);
    end else begin
      Canvas.Font.Assign(Fonts[0]);
    end;

    if Canvas.Font.Color <> item.fForeGroundColor then begin
      Canvas.Font.Color:= item.fForeGroundColor;
    end;

    rt.Top := actualArea.Top;
    rt.Bottom := actualArea.Bottom;

    // Copy the caption into a writable buffer for DrawTextEx (DT_MODIFYSTRING).
    // Cap the copy length so there is room for the terminating null and for the
    // up to 4 characters DT_END_ELLIPSIS may append, and pass the number of
    // characters actually present in the buffer rather than the untruncated
    // caption length.
    StrLCopy(labelBuffer,pchar(item.Caption),Length(labelBuffer)-5);
    Windows.DrawTextEx(
      Canvas.Handle,
      labelbuffer,
      StrLen(labelBuffer),
      rt,
      DT_CENTER or DT_VCENTER or DT_NOPREFIX or DT_MODIFYSTRING or DT_END_ELLIPSIS or DT_SINGLELINE,
      nil
    );
  end;
  //-------------------------------------------------------------------


  //-------------------------------------------------------------------
  // draw size info
  //-------------------------------------------------------------------
  rt.Left := actualArea.Left+BorderSize;
  rt.Top := actualArea.Top + BorderSize;
  rt.Bottom := actualArea.Bottom-BorderSize;
  rt.Right := actualArea.Right-BorderSize;

  tl:= Length(Item.Info);
  if tl > 0 then begin
    ratio:= rt.Width / tl;

    if ratio < 10  then begin
      Canvas.Font.Assign(Fonts[4]);
    end else
    if ratio < 15  then begin
      Canvas.Font.Assign(Fonts[3]);
    end else
    if ratio < 20  then begin
      Canvas.Font.Assign(Fonts[2]);
    end else
    if ratio < 25  then begin
      Canvas.Font.Assign(Fonts[1]);
    end else begin
      Canvas.Font.Assign(Fonts[0]);
    end;
  end;

  if Canvas.Font.Color <> item.fForeGroundColor then begin
    Canvas.Font.Color:= item.fForeGroundColor;
  end;

  rt.Top := actualArea.Top + (area.Height div 2)+Abs(Canvas.Font.Height);
  rt.Bottom := actualArea.Bottom-BorderSize;

  if rt.Bottom-rt.Height >= 24 then begin
    // Copy the info into a writable buffer for DrawTextEx (DT_MODIFYSTRING).
    // Same as with caption
    StrLCopy(labelBuffer,pchar(item.Info),Length(labelBuffer)-5);
    Windows.DrawTextEx(
      Canvas.Handle,
      labelBuffer,
      StrLen(labelBuffer),
      rt,
      DT_CENTER or DT_TOP or DT_NOPREFIX or DT_SINGLELINE ,
      nil
    );
    end;

  area:= remainingArea;

end;

function TDefaultTreeMapItemPainter.GenerateFont(asize: integer): TFont;
begin
  result:= TFont.Create;
  with result do begin
    Name:= 'Tahoma';
    Size:= asize;
    Color:= clBlack;
  end;
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// the actual treemap component
//------------------------------------------------------------------------------
{ TTreeMap }
constructor TTreeMap.Create(aowner: TComponent);
begin
  inherited;
  fBackgroundColor:= clBtnFace;
  fSelectionColor:= $FFFFFF;
  fBorderSize:= 1;

  fFont:= TFont.Create();
  fFont.Name:= 'Tahoma';
  fFont.Size:= 12;
  fFont.Color:= clBlack;

  fMaxItems:= 200;
  fMinArea:= 64*64;

  fDefaultItemPainter:= TDefaultTreeMapItemPainter.Create(fBorderSize,fSelectionColor, fFont.Name);

  fItems:= TTreeMapContainer.Create();
  fItems.fOnUpdate:= self.ItemsHaveUpdated;
  fUpdating:= false;

  fImages:= nil;
  fLastImages:= nil;
  fIcons:= TList.Create;
end;

procedure TTreeMap.DblClick;
begin
  exit;
end;

destructor TTreeMap.Destroy;
var
  i: integer;
begin
  for i:= 0 to fIcons.Count-1 do begin
    TIcon(fIcons[i]).Free;
    fIcons[i]:= nil;
  end;
  fIcons.Free;
  fItems.Free;
  fItems:= nil;

  fSurface.Free; // safe if the surface was never allocated (nil)
  fFont.Free;

  // fDefaultItemPainter always holds the component's own default painter.
  // A custom painter is injected through the OnDrawItem event and is never
  // owned here, so the type guard makes sure only the default painter is freed.
  if fDefaultItemPainter is TDefaultTreeMapItemPainter then fDefaultItemPainter.Free;

  inherited;
end;

function TTreeMap.FindItemAt(x, y: integer; aitems: TTreeMapContainer; recurse: boolean): TTreeMapItem;
var
  i: integer;
  b,c: TTreeMapItem;
  p: TPoint;
begin
  if aitems = nil then exit(nil);

  p:= Point(x,y);

  for i:= 0 to aitems.Count-1 do begin
    b:= TTreeMapItem(aitems[i]);

    if not(b.Rect.Contains(p)) then continue;

    if recurse and b.HasChildren then begin
      c:= FindItemAt(x,y,b.Children,true);
      if c <> nil then exit(c);
    end;

    exit(b);
  end;

  result:= nil;
end;

function TTreeMap.GetItemAt(x, y: integer): TTreeMapItem;
begin
  result:= FindItemAt(x,y,fItems,true);
end;

function TTreeMap.GetItemStates(aitem: TTreeMapItem): TTreeMapItemStates;
begin
  result:= [];
  if fHoverItem = aitem then begin
    result:= result + [tmisHighlight];
  end;
  if aitem.fSelected then begin
    result:= result + [tmisSelected];
  end;
  if aitem.fLastItem then result:= result + [tmisLast];
end;

procedure TTreeMap.SetSelected(const Value: TTreeMapItem; selected: boolean);
begin
  if value = nil then exit;
  if value.fSelected = selected then exit;
  value.fSelected:= selected;
  Repaint;
end;

procedure TTreeMap.ItemsHaveUpdated;
begin
  fMustRelayout:= true;
end;

procedure TTreeMap.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  fLastMouseButton:= button;
end;

procedure TTreeMap.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  UpdateHoverItem;
end;

procedure TTreeMap.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  p: TPoint;
  item: TTreeMapItem;
begin
  inherited;

  p:= CalcCursorPos;
  item:= GetItemAt(p.x,p.y);
  if item = nil then exit;

  if MilliSecondsBetween(fLastMouseUp,now) < 300 then begin
    if not(assigned(fOnDblClickItem)) then exit;
    fOnDblClickItem(self,item,Button,GetItemStates(item));
    exit;
  end;
  fLastMouseUp:= now;

  if not(assigned(fOnClickItem)) then exit;
  fOnClickItem(self,item,Button,GetItemStates(item));
end;

procedure TTreeMap.Paint;
begin
  if self.Parent = nil then exit;

  if not fUpdating then begin
    Render;
  end;
  Canvas.Draw(0,0,fSurface);
end;

procedure TTreeMap.Render;
var
  needsRescaling: boolean;
  r: TRect;
begin
  needsRescaling:= (fSurface = nil) or (fSurface.Width < self.Width) or (fSurface.Height < self.Height);
  if needsRescaling then begin
    fSurface.Free; // release the previous surface before allocating a new one (safe if nil)
    fSurface:= TBitmap.Create();
    fSurface.SetSize(Width+1000,Height+1000);
    fSurface.PixelFormat:= TPixelFormat.pf24bit;
    fSurface.AlphaFormat:= TAlphaFormat.afIgnored;
  end;

  r:= rect(0,0,Width,Height);
  ClearSurface(fSurface.Canvas,r);
  DrawTreemap(fSurface.Canvas,r,fItems);
end;

procedure TTreeMap.Repaint;
begin
  Paint;
end;

procedure TTreeMap.Resize;
begin
  fMustRelayout:= true;
  inherited;
end;

procedure TTreeMap.SetBorderSize(const Value: integer);
begin
  fBorderSize := Value;
  fDefaultItemPainter.Free;
  fDefaultItemPainter:= TDefaultTreeMapItemPainter.Create(fBorderSize,fSelectionColor,fFont.Name);
end;

procedure TTreeMap.SetFont(const Value: TFont);
begin
  fFont.Assign(Value); // copy into our owned font; do not take ownership of Value
  fDefaultItemPainter.Free;
  fDefaultItemPainter:= TDefaultTreeMapItemPainter.Create(fBorderSize,fSelectionColor,fFont.Name);
end;

procedure TTreeMap.SetSelectionColor(const Value: TColor);
begin
  fSelectionColor := Value;
  fDefaultItemPainter.Free;
  fDefaultItemPainter:= TDefaultTreeMapItemPainter.Create(fBorderSize,fSelectionColor,fFont.Name);
end;


procedure TTreeMap.SetMaxItems(const Value: integer);
begin
  fMaxItems := Value;
  fMustRelayout:= true;
  Repaint;
end;

procedure TTreeMap.SetMinArea(const Value: integer);
begin
  fMinArea := Value;
  fMustRelayout:= true;
  Repaint;
end;

procedure TTreeMap.UpdateHoverItem;
var
  p: TPoint;
  item: TTreeMapItem;
begin
  p:= CalcCursorPos;
  item:= GetItemAt(p.x,p.y);
  if item <> fHoverItem then begin
    fHoverItem:= item;
    Paint;
  end;
end;

procedure TTreeMap.UpdateIconCache;
var
  i: integer;
  c: TIcon;
begin
  if (fImages = fLastImages) then exit;
  fLastImages:= fImages;
  for i:= 0 to fIcons.Count-1 do begin
    TIcon(fIcons[i]).Free;
  end;
  fIcons.Clear;
  if fLastImages = nil then exit;
  for i:= 0 to fLastImages.Count-1 do begin
    c:= TIcon.Create;
    fLastImages.GetIcon(i,c);
    fIcons.Add(c);
  end;
end;

procedure ClearSelectionRecursive(aitems: TTreeMapContainer);
var
  i: integer;
begin
  for i:= 0 to aitems.Count-1 do begin
    aitems[i].fSelected:= false;
    if not(aitems[i].HasChildren) then continue;
    ClearSelectionRecursive(aitems[i].Children);
  end;
end;

procedure TTreeMap.ClearSelection;
begin
  ClearSelectionRecursive(fItems);
  Repaint;
end;

procedure TTreeMap.ClearSurface(acanvas: TCanvas; arect: TRect);
begin
  fSurface.Canvas.Brush.Color:= self.fBackgroundColor;
  fSurface.Canvas.FillRect(arect);
end;

procedure TTreeMap.CMMouseEnter(var Message: TMessage);
begin
  UpdateHoverItem;
end;

procedure TTreeMap.CMMouseLeave(var Message: TMessage);
begin
  UpdateHoverItem;
end;


procedure TTreeMap.DrawTreemap(acanvas: TCanvas; arect: TRect; aitems: TTreeMapContainer);
var
  i: integer;
  drawfunc: TOnDrawTreeMapItemEvent;
  item: TTreeMapItem;
  r: TRect;
begin
  if (aitems.fLayoutRect <> arect)
  or (aitems.fLayoutMaxItems <> fMaxItems)
  or (aitems.fLayoutMinArea <> fMinArea) then begin
    fMustRelayout:= true;
  end;

  if ((arect.Width*arect.Height) < self.MinArea) and (aitems <> fItems) then exit;

  if fMustRelayout then begin
    CalculateTreeMap(aitems,arect);
  end;

  drawfunc:= TDefaultTreeMapItemPainter(self.fDefaultItemPainter).DrawItem;
  if assigned(fOnDrawItem) then drawfunc:= fOnDrawItem;

  for i:= 0 to aitems.Count-1 do begin
    item:= aitems[i];

    r:= item.Rect;
    drawfunc(self,acanvas,item,GetItemStates(item),r);

    if item.HasChildren and (r.Width > 0) and (r.Height > 0) then begin
      DrawTreeMap(acanvas,r,item.children);
    end;

    if aitems[i].fLastItem then break;
  end;

  if aitems = fItems then fMustRelayout:= false;
end;

procedure TTreeMap.BeginUpdate;
begin
  fUpdating:= true;
end;

procedure TTreeMap.EndUpdate;
begin
  fUpdating:= false;
  fMustRelayout:= true;
  Repaint;
end;

procedure TTreeMap.CalculateTreemap(aitems: TTreeMapContainer; arect: TRect);
begin
  LayoutTreeMap(aitems,arect,fMaxItems,fMinArea);
  aitems.fLayoutRect:= arect;
  aitems.fLayoutMaxItems:= fMaxItems;
  aitems.fLayoutMinArea:= fMinArea;
end;
//------------------------------------------------------------------------------



procedure Register;
begin
  Classes.RegisterComponents('Fasko', [TTreemap]);
end;



end.
