{*******************************************************}
{                                                       }
{       Squarified Treemap Component Demo               }
{                                                       }
{       Copyright (c) 2026 Rezar Behzad & Ingo Jache    }
{       All rights reserved.                            }
{                                                       }
{       https://www.fe1.com/treemap/                    }
{       https://github.com/ijache/treemap               }
{                                                       }
{*******************************************************}
unit frmMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,Treemap, Vcl.ComCtrls,
  Vcl.StdCtrls,pngimage,shellapi, System.ImageList, Vcl.ImgList;

type
  TFormMain = class(TForm)
    StatusBar1: TStatusBar;
    Panel1: TPanel;
    Button1: TButton;
    Button2: TButton;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Button3: TButton;
    SaveDialog1: TSaveDialog;
    SomeIcons: TImageList;
    Label4: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private-Deklarationen }
    tm: TTreeMap;
    iconCounter: integer;
    procedure OnClickItem(Sender: TObject; Item: TTreeMapItem;
      Button: TMouseButton; State: TTreeMapItemStates);
    function NewItem(asize: int64; caption, subcaption: string; color: TColor): TTreeMapItem;
  public
    { Public-Deklarationen }

  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

function TFormMain.NewItem(asize: int64; caption: string; subcaption: string; color: TColor): TTreeMapItem;
begin
  result:= TTreeMapItem.Create(asize,caption,color,$f8f8f8,nil);
  result.ImageIndex:= iconCounter;
  result.Info:= subcaption;

  iconCounter:= (iconCounter + 1) mod SomeIcons.Count;

end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  iconCounter:= 0;

  // create the component, set basic properties...
  tm:= TTreeMap.Create(self);
  tm.BorderSize:= 4;
  tm.BackgroundColor:= $000000;
  tm.SelectionColor:= $0080FF;

  // add it to the form
  tm.Align:= alClient;
  tm.Parent:= self;

  tm.Images:= SomeIcons;

  // now add some items
  tm.BeginUpdate;
  tm.Items.Add(NewItem(10,'Biggest Item','some text',$203040));
  tm.Items.Add(NewItem(5,'Medium Item','some more text',$306040));
  tm.Items.Add(NewItem(3,'Smaller Item','this and that',$605040));
  tm.Items.Add(NewItem(1,'Tiny Item','these and those',$104060));
  tm.Items.Add(NewItem(1,'Tiny Item','more of that',$104060));
  tm.EndUpdate;

  // and also wire up the event-handler
  tm.OnClickItem:= self.OnClickItem;
end;


procedure TFormMain.FormDestroy(Sender: TObject);
begin
  tm.Free;
end;

procedure TFormMain.Button1Click(Sender: TObject);
var
  bigItem: TTreeMapItem;
  mediumItem: TTreeMapItem;
begin
  tm.BeginUpdate;

  // pick the biggest item...
  bigItem:= tm.Items[0];
  // .. and add some items
  bigItem.Children.Add(TTreeMapItem.Create(10,'A',$403040,$f8f8f8,nil));
  bigItem.Children.Add(TTreeMapItem.Create(5,'B',$603060,$f8f8f8,nil));
  bigItem.Children.Add(TTreeMapItem.Create(2,'C',$406040,$f8f8f8,nil));
  bigItem.Children.Add(TTreeMapItem.Create(1,'D',$604000,$f8f8f8,nil));
  bigItem.Children.Add(TTreeMapItem.Create(1,'E',$604040,$f8f8f8,nil));

  // pick the second biggest item...
  mediumItem:= tm.Items[1];
  // .. and add some items here too
  mediumItem.Children.Add(TTreeMapItem.Create(10,'a',$603010,$f8f8f8,nil));
  mediumItem.Children.Add(TTreeMapItem.Create(5,'b',$201060,$f8f8f8,nil));
  mediumItem.Children.Add(TTreeMapItem.Create(2,'c',$603040,$f8f8f8,nil));
  mediumItem.Children.Add(TTreeMapItem.Create(1,'d',$306040,$f8f8f8,nil));
  mediumItem.Children.Add(TTreeMapItem.Create(1,'e',$203040,$f8f8f8,nil));

  tm.EndUpdate;
end;

procedure TFormMain.Button2Click(Sender: TObject);
begin
  tm.BeginUpdate;
  // clear subitems from the two biggest items
  tm.Items[0].Children.Clear;
  tm.Items[1].Children.Clear;
  tm.EndUpdate;
end;


procedure TFormMain.OnClickItem(
    Sender: TObject;
    Item: TTreeMapItem;
    Button: TMouseButton;
    State: TTreeMapItemStates
);
begin
  // do not clear selection if shift key is down
  if (GetKeyState(VK_SHIFT) and $8000) = 0 then begin
    tm.ClearSelection;
  end;
  tm.SetSelected(item,not(item.selected));
end;

procedure TFormMain.Button3Click(Sender: TObject);
var
  png: TPNGImage;
begin
  if not(SaveDialog1.Execute) then exit;

  // create a blank png image
  png:= TPNGImage.CreateBlank(COLOR_RGB,8,1200,800);

  // draw treemap onto it
  tm.DrawTreemap(png.canvas,rect(0,0,png.width,png.height),tm.Items);

  // save png-file and open it via shell
  png.SaveToFile(SaveDialog1.Filename);
  png.Free;
  ShellExecute(self.Handle,nil,pwidechar(SaveDialog1.Filename),nil,nil,SW_SHOWNORMAL);
end;

end.
