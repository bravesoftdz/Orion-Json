unit Orion.Json.Helper;

interface

uses
  System.JSON,
  System.Rtti,
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections;

type
  TOrionJSON = class helper for TObject
  private
    function GetObjectInstance(aList: TObjectList<TObject>): TObject;
    procedure SetValueToObject(lProperty : TRttiProperty; aJson : TJSONObject);
    procedure SetValueToJson(lProperty : TRttiProperty; var aJson : TJSONObject);
    procedure SetValueToJsonArray(aObjectList: TObjectList<TObject>; var aJson: TJSONArray);
    procedure GetPairValue(var lPairValue: TJSONValue; aJson: TJSONObject; lProperty: TRttiProperty);
    procedure SetValueToObjectList(aValue: string; aList : TObjectList<TObject>);
  public
    procedure FromJSON(aValue : string); overload;
    procedure FromJSON(aValue : TJSONObject); overload;
    procedure FromJSON(aValue : TJSONArray); overload;
    function ToJSONString(aPretty : boolean = false) : string;
    function ToJSONObject : TJSONObject;
    function ToJSONArray : TJSONArray;
  end;

implementation

{ TOrionJSON }

procedure TOrionJSON.FromJSON(aValue: string);
var
  lJson : TJSONValue;
  lContext : TRttiContext;
  lType : TRttiType;
  lProperty: TRttiProperty;
begin
  lJson := TJSONValue.ParseJSONValue(aValue);
  lContext := TRttiContext.Create;
  lType := lContext.GetType(Self.ClassInfo);
  try
    if lJson is TJSONObject then begin
      for lProperty in lType.GetProperties do begin
        SetValueToObject(lProperty, TJSONObject(lJson));
      end;
    end
    else if lJson is TJSONArray then begin
      if Self.ClassName.Contains('TObjectList<') then begin
        TObjectList<TObject>(Self).Clear;
        SetValueToObjectList(lJson.ToJSON, TObjectList<TObject>(Self));
      end;

    end;
  finally
    FreeAndNil(lJson);
    FreeAndNil(lType);
  end;
end;

procedure TOrionJSON.SetValueToObjectList(aValue: string; aList : TObjectList<TObject>);
var
  I: Integer;
  lObject: TObject;
  lJsonArray : TJSONArray;
begin
  lJsonArray := TJSONArray.ParseJSONValue(aValue) as TJSONArray;
  if not Assigned(lJsonArray) then
    Exit;
  try
    for I := 0 to Pred(lJsonArray.Count) do
    begin
      lObject := GetObjectInstance(aList);
      lObject.FromJSON(TJSONObject(lJsonArray.Items[i]));
      aList.Add(lObject);
    end;
  finally
    FreeAndNil(lJsonArray);
  end;
end;

function TOrionJSON.ToJSONArray: TJSONArray;
var
  lJsonArray : TJSONArray;
begin
  Result := nil;
  if not Self.QualifiedClassName.Contains('TObjectList<') then
    Exit;

  lJsonArray := TJSONArray.Create;
  SetValueToJsonArray(TObjectList<TObject>(Self), lJsonArray);
  Result := lJsonArray;
end;

function TOrionJSON.ToJSONObject: TJSONObject;
var
  lContext : TRttiContext;
  lType : TRttiType;
  lProperty : TRttiProperty;
begin
  lContext := TRttiContext.Create;
  lType := lContext.GetType(Self.ClassInfo);
  try
    Result := TJSONObject.Create;
    for lProperty in lType.GetProperties do begin
      SetValueToJson(lProperty, Result);
    end;
  finally
    FreeAndNil(lType);
  end;
end;

function TOrionJSON.ToJSONString(aPretty : boolean = false) : string;
var
  lJson : TJSONObject;
  lJsonArray : TJSONArray;
begin
  if Self.QualifiedClassName.Contains('TObjectList<') then begin
    lJsonArray := TJSONArray.Create;
    try
      SetValueToJsonArray(TObjectList<TObject>(Self), lJsonArray);
      if aPretty then
        Result := lJsonArray.Format
      else
        Result := lJsonArray.ToJSON;
    finally
      FreeAndNil(lJsonArray);
    end;
  end
  else begin
    lJson := Self.ToJSONObject;
    try
      if aPretty then
        Result := lJson.Format
      else
        Result := lJson.ToJSON;
    finally
      FreeAndNil(lJson);
    end;
  end;
end;

procedure TOrionJSON.FromJSON(aValue: TJSONObject);
var
  lContext : TRttiContext;
  lType : TRttiType;
  lProperty: TRttiProperty;
begin
  lContext := TRttiContext.Create;
  lType := lContext.GetType(Self.ClassInfo);
  try
    for lProperty in lType.GetProperties do begin
      SetValueToObject(lProperty, aValue);
    end;
  finally
    FreeAndNil(lType);
  end;
end;

procedure TOrionJSON.FromJSON(aValue: TJSONArray);
var
  lContext : TRttiContext;
  lType : TRttiType;
begin
  lContext := TRttiContext.Create;
  lType := lContext.GetType(Self.ClassInfo);
  try
    if Self.ClassName.Contains('TObjectList<') then begin
      TObjectList<TObject>(Self).Clear;
      SetValueToObjectList(aValue.ToJSON, TObjectList<TObject>(Self));
    end;
  finally
    FreeAndNil(lType);
  end;
end;

function TOrionJSON.GetObjectInstance(aList: TObjectList<TObject>): TObject;
var
  lContext : TRttiContext;
  lType : TRttiType;
  lTypeName : string;
  lMethodType : TRttiMethod;
  lMetaClass : TClass;
begin
  lContext := TRttiContext.Create;
  lTypeName := Copy(aList.QualifiedClassName, 41, aList.QualifiedClassName.Length-41);
  lType := lContext.FindType(lTypeName);
  lMetaClass := nil;
  lMethodType := nil;
  if Assigned(lType) then begin
    for lMethodType in lType.GetMethods do begin
      if lMethodType.HasExtendedInfo and lMethodType.IsConstructor and (Length(lMethodType.GetParameters) = 0) then begin
        lMetaClass := lType.AsInstance.MetaclassType;
        Break;
      end;
    end;
  end;

  Result := lMethodType.Invoke(lMetaClass, []).AsObject;
end;

procedure TOrionJSON.GetPairValue(var lPairValue: TJSONValue; aJson: TJSONObject; lProperty: TRttiProperty);
var
  lCamelCasePairName: string;
begin
  lPairValue := aJson.FindValue(lProperty.Name);
  if not Assigned(lPairValue) then
  begin
    lCamelCasePairName := LowerCase((lProperty.Name.Chars[0]));
    lCamelCasePairName := lCamelCasePairName + Copy(lProperty.Name, 1, lProperty.Name.Length - 1);
    lPairValue := aJson.FindValue(lCamelCasePairName);
  end;
end;

procedure TOrionJSON.SetValueToJson(lProperty : TRttiProperty; var aJson : TJSONObject);
var
  lJsonArray : TJSONArray;
begin
  case lProperty.PropertyType.TypeKind of
    tkUnknown: ;
    tkInteger: aJson.AddPair(lProperty.Name, lProperty.GetValue(Pointer(Self)).AsInteger);
    tkChar: aJson.AddPair(lProperty.Name, lProperty.GetValue(Pointer(Self)).AsString);
    tkEnumeration: aJson.AddPair(lProperty.Name, lProperty.GetValue(Pointer(Self)).AsBoolean);
    tkFloat: begin
      if lProperty.PropertyType.QualifiedName.Contains('TDateTime') then
        aJson.AddPair(lProperty.Name, DateTimeToStr(lProperty.GetValue(Pointer(Self)).AsExtended))
      else
        aJson.AddPair(lProperty.Name, lProperty.GetValue(Pointer(Self)).AsExtended);
    end;
    tkString: aJson.AddPair(lProperty.Name, lProperty.GetValue(Pointer(Self)).AsString);
    tkWChar: aJson.AddPair(lProperty.Name, lProperty.GetValue(Pointer(Self)).AsString);
    tkLString: aJson.AddPair(lProperty.Name, lProperty.GetValue(Pointer(Self)).AsString);
    tkWString: aJson.AddPair(lProperty.Name, lProperty.GetValue(Pointer(Self)).AsString);
    tkInt64: aJson.AddPair(lProperty.Name, lProperty.GetValue(Pointer(Self)).AsInt64);
    tkUString: aJson.AddPair(lProperty.Name, lProperty.GetValue(Pointer(Self)).AsString);
    tkSet: ;
    tkClass: begin
      if lProperty.PropertyType.QualifiedName.Contains('TObjectList<') then begin
        lJsonArray := TJSONArray.Create;
        SetValueToJsonArray(TObjectList<TObject>(lProperty.GetValue(Pointer(Self)).AsObject), lJsonArray);
        aJson.AddPair(lProperty.Name, lJsonArray);
      end
      else begin
        aJson.AddPair(lProperty.Name, lProperty.GetValue(Pointer(Self)).AsObject.ToJSONObject);
      end;
    end;
    tkMethod: ;
    tkVariant: ;
    tkArray: ;
    tkRecord: ;
    tkInterface: ;
    tkDynArray: ;
    tkClassRef: ;
    tkPointer: ;
    tkProcedure: ;
    tkMRecord: ;
  end;

end;

procedure TOrionJSON.SetValueToJsonArray(aObjectList: TObjectList<TObject>; var aJson: TJSONArray);
var
  lJsonObject : TJSONObject;
  lObject : TObject;
begin
  for lObject in aObjectList do begin
    lJsonObject := lObject.ToJSONObject;
    aJson.Add(lJsonObject);
  end;
end;

procedure TOrionJSON.SetValueToObject(lProperty : TRttiProperty; aJson : TJSONObject);
var
  lPairValue : TJSONValue;
begin
  lPairValue := nil;
  GetPairValue(lPairValue, aJson, lProperty);

  if not Assigned(lPairValue) then
    Exit;

  try
    case lProperty.PropertyType.TypeKind of
      tkInteger: lProperty.SetValue(Pointer(Self), lPairValue.Value.ToInteger);
      tkChar: lProperty.SetValue(Pointer(Self), lPairValue.Value);
      tkEnumeration: begin
        if lProperty.PropertyType.QualifiedName.Contains('Boolean') then
          lProperty.SetValue(Pointer(Self), lPairValue.Value.ToBoolean);
      end;
      tkFloat: begin
        if lProperty.PropertyType.QualifiedName.Contains('TDateTime') then
          lProperty.SetValue(Pointer(Self), StrToDateTime(lPairValue.Value))
        else
          lProperty.SetValue(Pointer(Self), StrToFloat(lPairValue.Value.Replace('.', ',', [rfReplaceAll])));
      end;
      tkString: lProperty.SetValue(Pointer(Self), lPairValue.Value);
      tkWChar: lProperty.SetValue(Pointer(Self), lPairValue.Value);
      tkLString: lProperty.SetValue(Pointer(Self), lPairValue.Value);
      tkWString: lProperty.SetValue(Pointer(Self), lPairValue.Value);
      tkInt64: lProperty.SetValue(Pointer(Self), lPairValue.Value.ToInt64);
      tkUString: lProperty.SetValue(Pointer(Self), lPairValue.Value);
      tkDynArray: ;
      tkUnknown: ;
      tkSet: ;
      tkClass: begin
        if lProperty.PropertyType.QualifiedName.Contains('TObjectList<') then begin
          TObjectList<TObject>(lProperty.GetValue(Pointer(Self)).AsObject).Clear;
          SetValueToObjectList(lPairValue.Value, TObjectList<TObject>(lProperty.GetValue(Pointer(Self)).AsObject));
        end
        else
          lProperty.GetValue(Pointer(Self)).AsObject.FromJSON(lPairValue.Value);
      end;
      tkMethod: ;
      tkVariant: ;
      tkArray: ;
      tkRecord: ;
      tkInterface: ;
      tkClassRef: ;
      tkPointer: ;
      tkProcedure: ;
      tkMRecord: ;
    end;
  finally
  end;

end;

end.
