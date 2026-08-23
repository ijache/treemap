program Showcase;

uses
  Vcl.Forms,
  frmMain in 'frmMain.pas' {FormMain},
  Treemap in '..\..\src\Treemap.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
