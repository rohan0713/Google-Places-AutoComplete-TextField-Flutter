library google_location_autoComplete_textfield_flutter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_location_autocomplete_textfield_flutter/model/place_details.dart';
import 'package:google_location_autocomplete_textfield_flutter/model/place_type.dart';
import 'package:google_location_autocomplete_textfield_flutter/model/prediction.dart';

import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import 'DioErrorHandler.dart';

class GoogleLocationAutoCompleteTextField extends StatefulWidget {
  InputDecoration inputDecoration;
  ItemClick? itemClick;
  GetPlaceDetailswWithLatLng? getPlaceDetailWithLatLng;
  bool isLatLngRequired = true;

  TextStyle textStyle;
  String googleAPIKey;
  int debounceTime = 300;
  List<String>? countries = [];
  TextEditingController textEditingController = TextEditingController();
  ListItemBuilder? itemBuilder;
  Widget? seperatedBuilder;
  void clearData;
  BoxDecoration? boxDecoration;
  bool isCrossBtnShown;
  bool showError;
  double? containerHorizontalPadding;
  double? containerVerticalPadding;
  FocusNode? focusNode;
  PlaceType? placeType;
  String? language;
  Widget Function(BuildContext context)? noOptionsFoundBuilder;
  Widget Function(BuildContext context)? manualLocationBuilder;
  void Function(BuildContext context)? manualLocationClick;
  Color? suffixIconColor;
  AssetImage? suffixIcon;
  AssetImage? suffixIconAlternate;
  void Function(String)? onChanged;
  void Function()? onTapOutside;
  Color? dividerColor;

  GoogleLocationAutoCompleteTextField(
      {required this.textEditingController,
      required this.googleAPIKey,
      this.debounceTime: 600,
      this.inputDecoration: const InputDecoration(),
      this.itemClick,
      this.isLatLngRequired = true,
      this.textStyle: const TextStyle(),
      this.countries,
      this.getPlaceDetailWithLatLng,
      this.itemBuilder,
      this.boxDecoration,
      this.isCrossBtnShown = true,
      this.seperatedBuilder,
      this.showError = true,
      this.containerHorizontalPadding,
      this.containerVerticalPadding,
      this.focusNode,
      this.placeType,
      this.language = 'en',
      this.noOptionsFoundBuilder,
      this.manualLocationBuilder,
      this.manualLocationClick,
      this.suffixIconColor,
      this.suffixIcon,
      this.suffixIconAlternate,
      this.onChanged,
      this.onTapOutside,
      this.dividerColor});

  @override
  _GooglePlaceAutoCompleteTextFieldState createState() =>
      _GooglePlaceAutoCompleteTextFieldState();
}

class _GooglePlaceAutoCompleteTextFieldState
    extends State<GoogleLocationAutoCompleteTextField> {
  final subject = new PublishSubject<String>();
  final toggleSubject = PublishSubject<void>();
  OverlayEntry? _overlayEntry;
  List<Prediction> alPredictions = [];

  bool _isOverlayVisible = false;
  bool noOptionsFound = false;

  TextEditingController controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  bool isSearched = false;

  bool isCrossBtn = true;
  late var _dio;
  late FocusNode _focus;
  bool showManualLocation = true;
  bool showingPrediction = false;

  CancelToken? _cancelToken = CancelToken();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: widget.containerHorizontalPadding ?? 0,
            vertical: widget.containerVerticalPadding ?? 0),
        alignment: Alignment.centerLeft,
        decoration: widget.boxDecoration ??
            BoxDecoration(
                shape: BoxShape.rectangle,
                border: Border.all(color: Colors.grey, width: 0.6),
                borderRadius: BorderRadius.all(Radius.circular(10))),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                decoration: widget.inputDecoration.copyWith(
                    suffixIcon: InkWell(
                  onTap: () {
                    setState(() {
                      showingPrediction = !showingPrediction;
                    });

                    // if (alPredictions.length == 0 &&
                    //     widget.textEditingController.text.trim() != '') {
                    //   getLocation(widget.textEditingController.text.trim());
                    // }
                    if (widget.textEditingController.text.trim() != '' &&
                        showingPrediction) {
                      getLocation(widget.textEditingController.text.trim());
                    } else if (showingPrediction)
                      getLocation("");
                    else {
                      toggleSubject.add(null);
                    }
                  },
                  child: Container(
                      height: 16.0,
                      width: 16.0,
                      child: Center(
                        child: ImageIcon(
                          showingPrediction
                              ? widget.suffixIconAlternate
                              : widget.suffixIcon,
                          color: widget.suffixIconColor,
                          size: 10.0,
                        ),
                      )),
                )),
                style: widget.textStyle,
                controller: widget.textEditingController,
                focusNode: widget.focusNode ?? FocusNode(),
                onChanged: (string) {
                  subject.add(string);
                  if (widget.onChanged != null) {
                    setState(() {
                      showingPrediction = true;
                    });
                    widget.onChanged!(string);
                  }
                  if (widget.isCrossBtnShown) {
                    isCrossBtn = string.isNotEmpty ? true : false;
                    setState(() {});
                  }
                },
              ),
            ),
            (!widget.isCrossBtnShown)
                ? SizedBox()
                : isCrossBtn && _showCrossIconWidget()
                    ? IconButton(onPressed: clearData, icon: Icon(Icons.close))
                    : SizedBox()
          ],
        ),
      ),
    );
  }

  getLocation(String text) async {
    String apiURL =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$text&key=${widget.googleAPIKey}&language=${widget.language}";

    if (widget.countries != null) {
      // in

      for (int i = 0; i < widget.countries!.length; i++) {
        String country = widget.countries![i];

        if (i == 0) {
          apiURL = apiURL + "&components=country:$country";
        } else {
          apiURL = apiURL + "|" + "country:" + country;
        }
      }
    }
    if (widget.placeType != null) {
      apiURL += "&types=${widget.placeType?.apiString}";
    }

    if (_cancelToken?.isCancelled == false) {
      _cancelToken?.cancel();
      _cancelToken = CancelToken();
    }

    print("urlll $apiURL");
    try {
      String proxyURL = "https://cors-anywhere.herokuapp.com/";
      String url = kIsWeb ? proxyURL + apiURL : apiURL;

      /// Add the custom header to the options
      final options = kIsWeb
          ? Options(headers: {"x-requested-with": "XMLHttpRequest"})
          : null;
      Response response = await _dio.get(url);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      Map map = response.data;
      if (map.containsKey("error_message")) {
        throw response.data;
      }

      PlacesAutocompleteResponse subscriptionResponse =
          PlacesAutocompleteResponse.fromJson(response.data);

      // if (text.length == 0) {
      //   alPredictions.clear();
      //   noOptionsFound = false;
      //   showManualLocation = false;
      //   setState(() {
      //     showingPrediction = false;
      //   });
      //   this._overlayEntry!.remove();
      //   return;
      // }

      isSearched = false;
      alPredictions.clear();
      if (subscriptionResponse.predictions!.length > 0 &&
          (widget.textEditingController.text.toString().trim()).isNotEmpty) {
        alPredictions.addAll(subscriptionResponse.predictions!);
        showManualLocation = true;
        noOptionsFound = false;
      } else {
        showManualLocation = true;
        noOptionsFound = true;

        // showManualLocation = false;
        // noOptionsFound = true;
      }
      this._overlayEntry = null;
      this._overlayEntry = this._createOverlayEntry();
      Overlay.of(context)!.insert(this._overlayEntry!);
    } catch (e) {
      var errorHandler = ErrorHandler.internal().handleError(e);
      // _showSnackBar("${errorHandler.message}");
    }
  }

  @override
  void initState() {
    super.initState();
    _dio = Dio();
    subject.stream
        .distinct()
        .debounceTime(Duration(milliseconds: widget.debounceTime))
        .listen(textChanged);

    toggleSubject.debounceTime(Duration(milliseconds: 300)).listen((_) {
      toggleOverlay();
    });

    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        if (noOptionsFound) {
          hideOverlay();
          widget.onTapOutside?.call();
        } else {
          hideOverlay();
        }
      }
    });
  }

  textChanged(String text) async {
    widget.textEditingController.text = text;
    getLocation(text);
  }

  OverlayEntry? _createOverlayEntry() {
    if (context != null && context.findRenderObject() != null) {
      _isOverlayVisible = true;
      RenderBox renderBox = context.findRenderObject() as RenderBox;
      var size = renderBox.size;
      var offset = renderBox.localToGlobal(Offset.zero);
      return OverlayEntry(
          builder: (context) => Positioned(
                left: offset.dx,
                top: size.height + offset.dy,
                width: size.width,
                child: CompositedTransformFollower(
                  showWhenUnlinked: false,
                  link: this._layerLink,
                  offset: Offset(0.0, size.height + 5.0),
                  child: Material(
                    child: Container(
                      constraints: BoxConstraints(maxHeight: 250),
                      child: SingleChildScrollView(
                          child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          showManualLocation
                              ? InkWell(
                                  onTap: () {
                                    if (widget.manualLocationClick != null) {
                                      removeOverlay();
                                      widget.manualLocationClick!(context);
                                    }
                                  },
                                  child: widget.manualLocationBuilder != null
                                      ? widget.manualLocationBuilder
                                          ?.call(context)
                                      : const SizedBox(),
                                )
                              : const SizedBox(),
                          showManualLocation
                              ? Container(
                                  width: double.infinity,
                                  height: 1.0,
                                  color: widget.dividerColor,
                                )
                              : const SizedBox(),
                          ListView.separated(
                            primary: false,
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: alPredictions.length,
                            separatorBuilder: (context, pos) =>
                                widget.seperatedBuilder ?? SizedBox(),
                            itemBuilder: (BuildContext context, int index) {
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    showingPrediction = false;
                                  });
                                  var selectedData = alPredictions[index];
                                  if (index < alPredictions.length) {
                                    widget.itemClick!(selectedData);

                                    if (widget.isLatLngRequired) {
                                      getPlaceDetailsFromPlaceId(selectedData);
                                    }
                                    removeOverlay();
                                  }
                                },
                                child: widget.itemBuilder != null
                                    ? widget.itemBuilder!(
                                        context, index, alPredictions[index])
                                    : Container(
                                        padding: EdgeInsets.all(10),
                                        child: Text(
                                            alPredictions[index].description!)),
                              );
                            },
                          )
                        ],
                      )),
                    ),
                  ),
                ),
              ));
    }
  }

  void toggleOverlay() {
    // if (alPredictions.isNotEmpty) {
    if (_isOverlayVisible) {
      hideOverlay();
    } else {
      showOverlay();
    }
    // }
  }

  void showOverlay() {
    if (alPredictions.length == 0 &&
        widget.textEditingController.text.trim() != '') {
      getLocation(widget.textEditingController.text.trim());
    }
    this._isOverlayVisible = true;
  }

  void hideOverlay() {
    if (this._overlayEntry != null) {
      showManualLocation = false;
      removeOverlay();
      _isOverlayVisible = false;
    }
  }

  removeOverlay() {
    setState(() {
      showingPrediction = false;
    });
    showManualLocation = false;
    alPredictions.clear();
    this._overlayEntry = this._createOverlayEntry();
    _isOverlayVisible = false;
    if (context != null) {
      Overlay.of(context)!.insert(this._overlayEntry!);
    }
  }

  Future<Response?> getPlaceDetailsFromPlaceId(Prediction prediction) async {
    //String key = GlobalConfiguration().getString('google_maps_key');

    var url =
        "https://maps.googleapis.com/maps/api/place/details/json?placeid=${prediction.placeId}&key=${widget.googleAPIKey}";
    try {
      Response response = await _dio.get(
        url,
      );

      PlaceDetails placeDetails = PlaceDetails.fromJson(response.data);

      prediction.lat = placeDetails.result!.geometry!.location!.lat.toString();
      prediction.lng = placeDetails.result!.geometry!.location!.lng.toString();

      widget.getPlaceDetailWithLatLng!(prediction);
    } catch (e) {
      var errorHandler = ErrorHandler.internal().handleError(e);
      // _showSnackBar("${errorHandler.message}");
    }
  }

  void clearData() {
    widget.textEditingController.clear();
    if (_cancelToken?.isCancelled == false) {
      _cancelToken?.cancel();
    }

    setState(() {
      alPredictions.clear();
      isCrossBtn = false;
    });

    if (this._overlayEntry != null) {
      try {
        this._overlayEntry?.remove();
      } catch (e) {}
    }
  }

  _showCrossIconWidget() {
    return (widget.textEditingController.text.isNotEmpty);
  }

  _showSnackBar(String errorData) {
    if (widget.showError) {
      final snackBar = SnackBar(
        content: Text("$errorData"),
      );

      // Find the ScaffoldMessenger in the widget tree
      // and use it to show a SnackBar.
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }
}

PlacesAutocompleteResponse parseResponse(Map responseBody) {
  return PlacesAutocompleteResponse.fromJson(
      responseBody as Map<String, dynamic>);
}

PlaceDetails parsePlaceDetailMap(Map responseBody) {
  return PlaceDetails.fromJson(responseBody as Map<String, dynamic>);
}

typedef ItemClick = void Function(Prediction postalCodeResponse);
typedef GetPlaceDetailswWithLatLng = void Function(
    Prediction postalCodeResponse);

typedef ListItemBuilder = Widget Function(
    BuildContext context, int index, Prediction prediction);