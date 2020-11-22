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
  CastleControls, CastleColors, CastleUIControls,
  CastleCameras, CastleApplicationProperties, CastleLog,
  CastleSceneCore, CastleVectors, CastleScene, CastleViewport,
  X3DNodes, X3DFields, X3DTIme,
  CastleImages, CastleTimeUtils, CastleKeysMouse;

type

  TMyEventListener = class(TComponent)
    procedure ReceivedTouchTime(Event: TX3DEvent; Value: TX3DField; const Time: TX3DTime);
    procedure ReceivedIsActive(Event: TX3DEvent; Value: TX3DField; const Time: TX3DTime);
  end;

  { TCastleApp }

  {$ifndef cgeapp}
  TCastleApp = class(TForm)
    Window: TCastleControlBase;
    procedure FormDestroy(Sender: TObject);
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
    ColorChoice: Integer;
    MasterTexture: TRGBAlphaImage;
    MasterMetalTexture: TRGBAlphaImage;
    LabelSpare: TCastleLabel;
    LabelFPS: TCastleLabel;
    LabelClick: TCastleLabel;
    LabelRender: TCastleLabel;
    DoingRecolor: Boolean;
    RecolorTime: Int64;
    CacheTime: Int64;
    RecolorCount: Int64;
    GLIsReady: Boolean;
    NewColor: TVector4Byte;
    EventListener: TMyEventListener;
  public
    procedure RunCGEApplication(Sender: TObject);
    procedure KillCGEApplication(Sender: TObject);
    procedure LoadScene(Sender: TObject; filename: String);
    procedure CreateLabel(var objLabel: TCastleLabel; const Line: Integer; const BottomUp: Boolean = True);
    function ChangeTexture(const Node: TX3DRootNode; const Texture: TCastleImage): TVector3Cardinal;
    function RecolorImage(const ImageIn: TRGBAlphaImage; const NewRGB: TVector4Byte): TRGBAlphaImage;
    function LoadMasterTexture(filename: String): TRGBAlphaImage;
    procedure HoverClick(Sender: TObject);
    procedure AddSensor(AScene: TCastleScene; AColor: TVector4Byte);
    procedure PaintJob;
  end;

var
{$ifndef cgeapp}
  CastleApp: TCastleApp;
{$endif}
  LabelT1: TCastleLabel;
  LabelT2: TCastleLabel;
  evt_t1, evt_t2, evt_tc: Integer;

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

function Vec4BtoInt(const AValue: TVector4Byte): Cardinal;

implementation
{$ifdef cgeapp}
uses GameInitialize;
{$endif}

{$ifndef cgeapp}
{$R *.lfm}
{$endif}

procedure TMyEventListener.ReceivedTouchTime(Event: TX3DEvent; Value: TX3DField; const Time: TX3DTime);
var
  Val: Double;
begin
  Val := (Value as TSFTime).Value;
  Inc(evt_t1);
  LabelT1.Caption := Format('Received %d TouchSensor.touchTime event: time %f', [evt_t1, Val]);
end;

procedure TMyEventListener.ReceivedIsActive(Event: TX3DEvent; Value: TX3DField; const Time: TX3DTime);
var
  Val: Boolean;
begin
  Val := (Value as TSFBool).Value;
  Inc(evt_t2);
  LabelT2.Caption := Format('Received %d TouchSensor.isActive event: %s', [evt_t2, BoolToStr(Val, true)]);
end;

{ TCastleApp }

function TCastleApp.RecolorImage(const ImageIn: TRGBAlphaImage; const NewRGB: TVector4Byte): TRGBAlphaImage;
var
  ImageOut: TRGBAlphaImage;
  PSource, PDest: PVector4Byte;
  x, y: Integer;
  SeekRGB: TVector4Byte;
  ReplaceRGB: TVector4Byte;
begin
  ImageOut := nil;
  SeekRGB := Vector4Byte(255, 255, 255, 255);
  ReplaceRGB := NewRGB;
  if not(ImageIn = nil) then
    begin
      if not(ImageIn.Dimensions.IsZero) then
        begin
          ImageOut := TRGBAlphaImage.Create(ImageIn.Dimensions.X, ImageIn.Dimensions.Y);
          PSource := ImageIn.PixelPtr(0, 0);
          PDest := ImageOut.PixelPtr(0, 0);
          for y := 0 to ImageIn.Dimensions.Y -1 do
            begin
              for x := 0 to ImageIn.Dimensions.X -1 do
                begin
                  if TVector4Byte.Equals(PSource^, SeekRGB) then
                    PDest^ := ReplaceRGB
                  else
                    PDest^ := PSource^;
                  Inc(PSource);
                  Inc(PDest);
                end;
            end;
        end;
    end;
  Result := ImageOut;
end;

function TCastleApp.LoadMasterTexture(filename: String): TRGBAlphaImage;
var
  Texture: TRGBAlphaImage;
begin
  try
    Texture := LoadImage(filename, [TRGBAlphaImage]) as TRGBAlphaImage;
  except
    on E : Exception do
      begin
        {$ifndef cgeapp}
        ShowMessage('Exception' + LineEnding +
                    'Trying to load : ' + filename + LineEnding +
                     E.ClassName + LineEnding +
                     E.Message);
        {$endif}
        Texture := nil;
       end;
  end;
  Result := Texture;
end;

procedure TCastleApp.HoverClick(Sender: TObject);
begin
  if Sender is TTouchSensorNode then
    begin
//      MenuValue := ExtractX3DTag(TTouchSensorNode(Sender).X3DName, 'MenuTouch_');
      Inc(evt_tc);
      LabelClick.Caption := 'Received MenuClick ' + IntToStr(evt_tc) + ' (' + TTouchSensorNode(Sender).X3DName + ')';
      PaintJob;
    end;
end;

procedure TCastleApp.AddSensor(AScene: TCastleScene; AColor: TVector4Byte);
var
  TouchSensor: TTouchSensorNode;
begin
  if not(AScene = nil) then
    begin
    TouchSensor := AScene.RootNode.TryFindNodeByName(TTouchSensorNode, 'TextureColor', false) as TTouchSensorNode;
    if TouchSensor = nil then
      begin
        TouchSensor := TTouchSensorNode.Create('TextureColor');
        TouchSensor.Enabled := true;
        TouchSensor.Onclick := @HoverClick;
        TouchSensor.EventTouchTime.AddNotification(@EventListener.ReceivedTouchTime);
        TouchSensor.EventIsActive.AddNotification(@EventListener.ReceivedIsActive);
        AScene.RootNode.AddChildren(TouchSensor);
        LabelT1.Caption := 'Sensor set';
      end;
  //  Vec4BtoInt(NewColor);
    end
  else
    LabelT1.Caption := 'Sensor not set';
end;

function TCastleApp.ChangeTexture(const Node: TX3DRootNode; const Texture: TCastleImage): TVector3Cardinal;
var
  PhysicalMaterialNode: TPhysicalMaterialNode;
  PixelTextureNode: TPixelTextureNode;
  MetalTextureNode: TPixelTextureNode;
  AppearanceNode: TAppearanceNode;
begin
  Result := TVector3Cardinal.Zero;
  AppearanceNode := Node.TryFindNodeByName(TAppearanceNode, 'Glass', false) as TAppearanceNode;
  if not (AppearanceNode = nil) then
  begin
    PixelTextureNode := TPixelTextureNode.Create;
    PixelTextureNode.FdImage.Value := Texture;
    MetalTextureNode := TPixelTextureNode.Create;
    MetalTextureNode.FdImage.Value := MasterMetalTexture.MakeCopy;
    if PixelTextureNode.IsTextureImage then
      begin
        PhysicalMaterialNode := TPhysicalMaterialNode.Create;
        PhysicalMaterialNode.baseTexture := PixelTextureNode;
        PhysicalMaterialNode.baseTextureMapping := 'TEXCOORD_0';
        PhysicalMaterialNode.metallicRoughnessTextureMapping := 'TEXCOORD_0';
        PhysicalMaterialNode.metallicRoughnessTexture := MetalTextureNode;
        AppearanceNode.Material := PhysicalMaterialNode;
        Result := PixelTextureNode.TextureImage.Dimensions;
      end;
  end;
end;

procedure TCastleApp.CreateLabel(var objLabel: TCastleLabel; const Line: Integer; const BottomUp: Boolean = True);
begin
  objLabel := TCastleLabel.Create(Application);
  objLabel.Padding := 5;
  objLabel.Color := White;
  objLabel.Frame := True;
  objLabel.FrameColor := Black;
  objLabel.Anchor(hpLeft, 10);
  if BottomUp then
    objLabel.Anchor(vpBottom, 10 + (Line * 35))
  else
    objLabel.Anchor(vpTop, -(10 + (Line * 35)));
  Window.Controls.InsertFront(objLabel);
end;

function Vec4BtoInt(const AValue: TVector4Byte): Cardinal;
begin
  Result := (AValue.X << 16) or (AValue.Y << 8) or AValue.Z;
end;

procedure TCastleApp.PaintJob;
var
  TempImage: TRGBAlphaImage;
  ReColorTimer: Int64;
  CacheTimer: Int64;
begin
  if not (Scene = nil) and not(DoingRecolor) then
    begin
      DoingRecolor := True;
      ReColorTimer := CastleGetTickCount64;
      NewColor := Vector4Byte(random(256), random(256), random(256), 255);
      TempImage := RecolorImage(MasterTexture, NewColor);
      if not(TempImage = nil) then
        begin
          ReColorTimer := CastleGetTickCount64 - ReColorTimer;
          CacheTimer := CastleGetTickCount64;
          ChangeTexture(Scene.RootNode, TempImage);
          CacheTimer := CastleGetTickCount64 - CacheTimer;
        end;
      RecolorTime += ReColorTimer;
      CacheTime += CacheTimer;
      Inc(RecolorCount);
      LabelSpare.Caption := 'ReColor = ' +
                           FormatFloat('####0.000', ReColorTimer / 1000) +
                           ' seconds' + LineEnding +
                           'Average ReColor = ' +
                           FormatFloat('####0.000', (RecolorTime / RecolorCount) / 1000) +
                           ' seconds (' + IntToStr(RecolorCount) + ' ReColors)' +
                            LineEnding +'Apply Texture = ' +
                            FormatFloat('####0.000', CacheTimer / 1000) +
                            ' seconds' + LineEnding +
                            'Average Application = ' +
                            FormatFloat('####0.000', (CacheTime / RecolorCount) / 1000) +
                            ' seconds (' + IntToStr(RecolorCount) + ' ReColors)';

      DoingRecolor := False;
    end;

end;

procedure TCastleApp.LoadScene(Sender: TObject; filename: String);
var
  TempImage: TRGBAlphaImage;
begin
  // Set up the main viewport
  Viewport := TCastleViewport.Create(Application);
  // Use all the viewport
  Viewport.FullSize := true;
  // Automatically position the camera
  Viewport.AutoCamera := true;
  // Use default navigation keys
  Viewport.AutoNavigation := true;

  MasterTexture := LoadMasterTexture('castle-data:/HoverRacerReColor.png');
  MasterMetalTexture := LoadMasterTexture('castle-data:/HoverRacerReColor_maps.png');

  // Add the viewport to the CGE control
  {$ifndef cgeapp}
  Window.Controls.InsertFront(Viewport);
  {$else}
  TCastleWindowBase(Sender).Controls.InsertFront(Viewport);
  {$endif}

  Scene := TCastleScene.Create(Application);
  // Load a model into the scene
  Scene.Load(filename);

  TempImage := RecolorImage(MasterTexture, NewColor); // Red at initialization
  ChangeTexture(Scene.RootNode, TempImage);
  Scene.ProcessEvents := true;
  Scene.Spatial := [ssRendering, ssDynamicCollisions];

  // Add the scene to the viewport
  Viewport.Items.Add(Scene);

  // Tell the control this is the main scene so it gets some lighting
  Viewport.Items.MainScene := Scene;

  CreateLabel(LabelSpare, 0, False);
  CreateLabel(LabelT1, 4);
  CreateLabel(LabelT2, 3);
  CreateLabel(LabelClick, 2);
  CreateLabel(LabelFPS, 1);
  CreateLabel(LabelRender, 0);
end;

procedure TCastleApp.RunCGEApplication(Sender: TObject);
begin
  DoingRecolor := False;
  GLIsReady := False;
  RecolorTime := 0;
  CacheTime := 0;
  RecolorCount := 0;
  ColorChoice := 0;
  Scene := nil;
  evt_t1 := 0;
  evt_t2 := 0;
  evt_tc := 0;
  MasterTexture := nil;
  MasterMetalTexture := nil;
  EventListener := TMyEventListener.Create(Application);
  NewColor := Vector4Byte(255, 0, 0, 255); // Default to Red
  LoadScene(Sender, 'castle-data:/HoverRacer.gltf');
end;

procedure TCastleApp.KillCGEApplication(Sender: TObject);
begin
  FreeAndNil(MasterTexture);
  FreeAndNil(MasterMetalTexture);
end;

{$ifndef cgeapp}
procedure TCastleApp.FormCreate(Sender: TObject);
begin
  Caption := 'Hover CGE Lazarus Application';
  RunCGEApplication(Sender);
end;

procedure TCastleApp.FormDestroy(Sender: TObject);
begin
  KillCGEApplication(Sender);
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
  if GLIsReady then
    begin
    LabelFPS.Caption := 'FPS = ' + FormatFloat('####0.00', Window.Fps.RealFps);
    LabelRender.Caption := 'Render = ' + FormatFloat('####0.00', Window.Fps.OnlyRenderFps);

    // Set angle (theta) to revolve completely once every SecsPerRot
    theta := ((CastleGetTickCount64 mod
              (SecsPerRot * 1000)) /
              (SecsPerRot * 1000)) * (Pi * 2);

    // Rotate the scene in Y
    // Change to Vector4(1, 0, 0, theta); to rotate in X

    Scene.Rotation := Vector4(0, 1, 0, theta);
    end;
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
  GLIsReady := True;
  AddSensor(Scene, NewColor);
  {$ifdef cgeapp}end;{$endif}
end;

{$ifdef cgeapp}
procedure WindowPress(Sender: TUIContainer;
  const Event: TInputPressRelease);
{$else}
procedure TCastleApp.WindowPress(Sender: TObject;
  const Event: TInputPressRelease);
{$endif}
var
  TempImage: TRGBAlphaImage;
begin
  {$ifdef cgeapp}with CastleApp do begin{$endif}
  {$ifndef darwin}
  if Event.IsKey(keyX) then
    begin
      TempImage := RecolorImage(MasterTexture, NewColor);
      SaveImage(TempImage, 'castle-data:/exportedTextures/HoverRacer_temp.png');
      FreeAndNil(TempImage);
    end;
  {$endif}

  if Event.IsKey(keySpace) then
    begin
      PaintJob;
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

