unit MainGameUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  {$ifndef cgeapp}
  Forms, Controls, Graphics, Dialogs, CastleControl, CastleLCLUtils,
  {$else}
  CastleWindow,
  {$endif}
  CastleCameras, CastleApplicationProperties, CastleLog,
  CastleSceneCore, CastleVectors, CastleScene, CastleViewport,
  X3DNodes, CastleImages, CastleTimeUtils, CastleKeysMouse;

type

  { TCastleApp }

  {$ifndef cgeapp}
  TCastleApp = class(TForm)
    Window: TCastleControlBase;
    procedure WindowBeforeRender(Sender: TObject);
    procedure WindowClose(Sender: TObject);
    procedure WindowMotion(Sender: TObject; const Event: TInputMotion);
    procedure WindowOpen(Sender: TObject);
    procedure WindowPress(Sender: TObject; const Event: TInputPressRelease);
    procedure WindowRelease(Sender: TObject; const Event: TInputPressRelease);
    procedure WindowRender(Sender: TObject);
    procedure WindowResize(Sender: TObject);
    procedure WindowUpdate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  {$else}
  TCastleApp = class(TWindowContainer)
  {$endif}
  private
    Viewport: TCastleViewport;
    Scene: TCastleScene;
    colour: Integer;
  public
    procedure RunCGEApplication(Sender: TObject);
    procedure LoadScene(Sender: TObject; filename: String);
    function ChangeTexture(const Node: TX3DRootNode; const TextureUrl: String): TVector3Cardinal;
  end;

{$ifndef cgeapp}
var
  CastleApp: TCastleApp;
{$endif}

const
  InitialSet: array [0 .. 2] of String =
      ('HoverRacer_Red.png',
       'HoverRacer_Green.png',
       'HoverRacer_Blue.png');

{$ifdef cgeapp}
procedure WindowBeforeRender(Sender: TUIContainer);
procedure WindowClose(Sender: TUIContainer);
procedure WindowMotion(Sender: TUIContainer; const Event: TInputMotion);
procedure WindowOpen(Sender: TUIContainer);
procedure WindowPress(Sender: TUIContainer; const Event: TInputPressRelease);
procedure WindowRelease(Sender: TUIContainer; const Event: TInputPressRelease);
procedure WindowRender(Sender: TUIContainer);
procedure WindowResize(Sender: TUIContainer);
procedure WindowUpdate(Sender: TUIContainer);
{$endif}

implementation
{$ifdef cgeapp}
uses GameInitialize;
{$endif}

{$ifndef cgeapp}
{$R *.lfm}
{$endif}

{ TCastleApp }

function TCastleApp.ChangeTexture(const Node: TX3DRootNode; const TextureUrl: String): TVector3Cardinal;
var
  TextureNode: TImageTextureNode;
  AppearanceNode: TAppearanceNode;
begin
  Result := TVector3Cardinal.Zero;
  AppearanceNode := Node.TryFindNodeByName(TAppearanceNode, 'Glass', false) as TAppearanceNode;
  if not (AppearanceNode = nil) then
  begin
    TextureNode := AppearanceNode.MainTexture as TImageTextureNode;
    if not (TextureNode = nil) then
      begin
        TextureNode.SetUrl(TextureUrl);
        if TextureNode.IsTextureImage then
          Result := TextureNode.TextureImage.Dimensions;
      end;
  end;
end;

procedure TCastleApp.LoadScene(Sender: TObject; filename: String);
begin
  // Set up the main viewport
  Viewport := TCastleViewport.Create(Application);
  // Use all the viewport
  Viewport.FullSize := true;
  // Automatically position the camera
  Viewport.AutoCamera := true;
  // Use default navigation keys
  Viewport.AutoNavigation := true;

  // Add the viewport to the CGE control
  {$ifndef cgeapp}
  Window.Controls.InsertFront(Viewport);
  {$else}
  TCastleWindowBase(Sender).Controls.InsertFront(Viewport);
  {$endif}

  Scene := TCastleScene.Create(Application);
  // Load a model into the scene
  Scene.load(filename);
  ChangeTexture(Scene.RootNode, InitialSet[colour]);

  // Add the scene to the viewport
  Viewport.Items.Add(Scene);

  // Tell the control this is the main scene so it gets some lighting
  Viewport.Items.MainScene := Scene;
end;

procedure TCastleApp.RunCGEApplication(Sender: TObject);
begin
  colour := 0;
  Scene := nil;
  LoadScene(Sender, 'castle-data:/HoverRacer.gltf');
end;

{$ifndef cgeapp}
procedure TCastleApp.FormCreate(Sender: TObject);
begin
  Caption := 'Hover CGE Lazarus Application';
  RunCGEApplication(Sender);
end;
{$endif}

{$ifdef cgeapp}
procedure WindowBeforeRender(Sender: TUIContainer);
{$else}
procedure TCastleApp.WindowBeforeRender(Sender: TObject);
{$endif}
const
  // How many seconds to take to rotate the scene
  SecsPerRot = 4;
var
  theta: Single;
begin
  {$ifdef cgeapp}with CastleApp do begin{$endif}
  // Set angle (theta) to revolve completely once every SecsPerRot
  theta := ((CastleGetTickCount64 mod
            (SecsPerRot * 1000)) /
            (SecsPerRot * 1000)) * (Pi * 2);

  // Rotate the scene in Y
  // Change to Vector4(1, 0, 0, theta); to rotate in X

  Scene.Rotation := Vector4(0, 1, 0, theta);
  {$ifdef cgeapp}end;{$endif}
end;

{$ifdef cgeapp}
procedure WindowClose(Sender: TUIContainer);
{$else}
procedure TCastleApp.WindowClose(Sender: TObject);
{$endif}
begin
  {$ifdef cgeapp}with CastleApp do begin{$endif}
  {$ifdef cgeapp}end;{$endif}
end;

{$ifdef cgeapp}
procedure WindowMotion(Sender: TUIContainer; const Event: TInputMotion);
{$else}
procedure TCastleApp.WindowMotion(Sender: TObject; const Event: TInputMotion);
{$endif}
begin
  {$ifdef cgeapp}with CastleApp do begin{$endif}
  {$ifdef cgeapp}end;{$endif}
end;

{$ifdef cgeapp}
procedure WindowOpen(Sender: TUIContainer);
{$else}
procedure TCastleApp.WindowOpen(Sender: TObject);
{$endif}
begin
  {$ifdef cgeapp}with CastleApp do begin{$endif}
  {$ifdef cgeapp}end;{$endif}
end;

{$ifdef cgeapp}
procedure WindowPress(Sender: TUIContainer;
  const Event: TInputPressRelease);
{$else}
procedure TCastleApp.WindowPress(Sender: TObject;
  const Event: TInputPressRelease);
{$endif}
begin
  {$ifdef cgeapp}with CastleApp do begin{$endif}
  if Event.IsKey(keySpace) then
    begin
      if not (Scene = nil) then
        begin
          Inc(colour);
          if (colour >= Length(InitialSet)) then
            colour := 0;
          ChangeTexture(Scene.RootNode, InitialSet[colour]);
        end;
    end;
    {$ifdef cgeapp}end;{$endif}
end;

{$ifdef cgeapp}
procedure WindowRelease(Sender: TUIContainer;
  const Event: TInputPressRelease);
{$else}
procedure TCastleApp.WindowRelease(Sender: TObject;
  const Event: TInputPressRelease);
{$endif}
begin
  {$ifdef cgeapp}with CastleApp do begin{$endif}
  {$ifdef cgeapp}end;{$endif}
end;

{$ifdef cgeapp}
procedure WindowRender(Sender: TUIContainer);
{$else}
procedure TCastleApp.WindowRender(Sender: TObject);
{$endif}
begin
  {$ifdef cgeapp}with CastleApp do begin{$endif}
  {$ifdef cgeapp}end;{$endif}
end;

{$ifdef cgeapp}
procedure WindowResize(Sender: TUIContainer);
{$else}
procedure TCastleApp.WindowResize(Sender: TObject);
{$endif}
begin
  {$ifdef cgeapp}with CastleApp do begin{$endif}
  {$ifdef cgeapp}end;{$endif}
end;

{$ifdef cgeapp}
procedure WindowUpdate(Sender: TUIContainer);
{$else}
procedure TCastleApp.WindowUpdate(Sender: TObject);
{$endif}
begin
  {$ifdef cgeapp}with CastleApp do begin{$endif}
  {$ifdef cgeapp}end;{$endif}
end;

end.

