import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:filesize/filesize.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:watcher/watcher.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:oktoast/oktoast.dart';
import 'filepicker.dart';
import 'server.dart';
import 'network.dart';
import 'sharemanager.dart';

class StateManagerPage extends StatefulWidget {
  @override
  StateManager createState() => StateManager();
}

class StateManager extends State<StateManagerPage> {
  bool fileExists = false;
  bool interfaceUpdate = false;

  bool setFileStatus(bool state) {
    setState(() {
      fileExists = state;
    });

    return state;
  }

  // List of platforms considered to be desktop
  bool isDesktop = (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    Widget _outputState;
    if (FilePicker.fileImported) {
      _outputState = importedPage(context);
    } else {
      _outputState = landingPage(context);
    }
    return _outputState;
  }

  // Landing view
  Widget landingPage(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Card(
            color: const Color.fromRGBO(34, 34, 34, 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            elevation: 1,
            child: Container(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.insert_drive_file,
                    color: const Color.fromRGBO(255, 255, 255, 1.0),
                    size: 80.0,
                    semanticLabel:
                        AppLocalizations.of(context)!.page_landing_label,
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  AutoSizeText(
                    AppLocalizations.of(context)!.page_landing_msg,
                    textAlign: TextAlign.center,
                    minFontSize: 11,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Loading view
  Widget loadingPage() {
    return Column(
      children: <Widget>[
        Card(
          color: const Color.fromRGBO(34, 34, 34, 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40.0),
          ),
          elevation: 1,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  const Color.fromRGBO(255, 255, 255, 1.0)),
            ),
          ),
        ),
      ],
    );
  }

  Widget loadingIndicator() {
    return const SizedBox(
      width: 30,
      height: 30,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
            const Color.fromRGBO(255, 255, 255, 1.0)),
      ),
    );
  }

  // Error view
  Widget msgPage(int type, BuildContext context) {
    Map _msgInfo;

    // Reset state bypass
    interfaceUpdate = false;

    switch (type) {

      // No network
      case 0:
        {
          _msgInfo = {
            'icon': Icons.signal_wifi_off,
            'label': AppLocalizations.of(context)!.page_info_noconnection_label,
            'msg': AppLocalizations.of(context)!.page_info_noconnection_msg,
          };
        }
        break;

      // Snapshot error while gathering interface list
      case 1:
        {
          _msgInfo = {
            'icon': Icons.error,
            'label':
                AppLocalizations.of(context)!.page_info_snapshoterror_label,
            'msg': AppLocalizations.of(context)!.page_info_snapshoterror_msg,
          };
        }
        break;

      // Selected file was removed
      case 2:
        {
          _msgInfo = {
            'icon': Icons.block,
            'label': AppLocalizations.of(context)!.page_info_fileremoved_label,
            'msg': AppLocalizations.of(context)!.page_info_fileremoved_msg,
          };
        }
        break;

      // Storage permission declined
      case 3:
        {
          _msgInfo = {
            'icon': Icons.error,
            'label':
                AppLocalizations.of(context)!.page_info_permissiondenied_label,
            'msg': AppLocalizations.of(context)!.page_info_permissiondenied_msg,
          };
        }
        break;

      // Port reuse
      case 4:
        {
          _msgInfo = {
            'icon': Icons.error,
            'label': AppLocalizations.of(context)!.page_info_portinuse_label,
            'msg': AppLocalizations.of(context)!.page_info_portinuse_msg,
          };
        }
        break;

      default:
        {
          _msgInfo = {
            'icon': Icons.error,
            'label': AppLocalizations.of(context)!.page_info_fallback_label,
            'msg': AppLocalizations.of(context)!.page_info_fallback_msg +
                type.toString(),
          };
        }
        break;
    }

    return Column(
      children: <Widget>[
        Container(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Card(
            color: const Color.fromRGBO(34, 34, 34, 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            elevation: 1,
            child: Container(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: <Widget>[
                  Icon(
                    _msgInfo['icon'],
                    color: const Color.fromRGBO(255, 255, 255, 1.0),
                    size: 80.0,
                    semanticLabel: _msgInfo['label'],
                  ),
                  const SizedBox(height: 20),
                  AutoSizeText(
                    _msgInfo['msg'],
                    style: const TextStyle(fontSize: 13),
                    textAlign: TextAlign.center,
                    minFontSize: 11,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Imported view
  String defaultIP = '';
  String? selectedIP = '';
  bool fileInPath = false;

  Widget importedPage(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: Network().fetchInterfaces(context),
      builder: (context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
        if (snapshot.hasError) {
          return msgPage(1, context);
        } else if (snapshot.hasData && interfaceUpdate ||
            snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
          // Enable state bypass
          interfaceUpdate = true;
          // File information
          Map<String, dynamic> _fileInfo = FilePicker().readInfo();

          // Human readable file size
          String _sizeHuman = filesize(_fileInfo['length'], 2);
          _sizeHuman = _sizeHuman.replaceAll(
              'TB', AppLocalizations.of(context)!.page_imported_sizesymbol_tb);
          _sizeHuman = _sizeHuman.replaceAll(
              'GB', AppLocalizations.of(context)!.page_imported_sizesymbol_gb);
          _sizeHuman = _sizeHuman.replaceAll(
              'MB', AppLocalizations.of(context)!.page_imported_sizesymbol_mb);
          _sizeHuman = _sizeHuman.replaceAll(
              'KB', AppLocalizations.of(context)!.page_imported_sizesymbol_kb);
          _sizeHuman = _sizeHuman.replaceAll(' B',
              ' ' + AppLocalizations.of(context)!.page_imported_sizesymbol_b);
          _sizeHuman = _sizeHuman.replaceAll('.',
              AppLocalizations.of(context)!.page_imported_decimalseparator);

          // Only update on next full run or if selected IP is gone
          if (!snapshot.data!['interfaces'].contains(selectedIP.toString())) {
            // Use empty string if no initial IP address to choose from
            if (snapshot.data!['interfaces'].isEmpty) {
              defaultIP = '';
            } else {
              defaultIP = snapshot.data!['interfaces'][0];
            }

            // If no interfaces available, return network error page
            if (defaultIP == '') {
              Server().shutdownServer(context);
              return msgPage(0, context);
            }

            // Set default IP
            selectedIP = defaultIP;
          }

          // Check if server exception occurred
          if (Server.serverException) {
            Server.serverException = false;
            return msgPage(4, context);
          }

          String? _hostFormatted;
          String _filePath;

          // Formatting for IPv6
          if (!Network().checkIPV4(selectedIP)) {
            _hostFormatted = '[$selectedIP]';
          } else {
            _hostFormatted = selectedIP;
          }

          // Check if to include file name in path
          if (fileInPath) {
            _filePath = Uri.encodeComponent(_fileInfo['name']);
          } else {
            _filePath = '';
          }

          String _hostName =
              'http://$_hostFormatted:${snapshot.data!['port'].toString()}/$_filePath';

          fileExists = Server().fileExists(_fileInfo['path']);

          if (!fileExists) {
            return msgPage(2, context);
          }

          // File monitoring
          try {
            var watcher = DirectoryWatcher(_fileInfo['pathpart']);
            watcher.events.listen((event) {
              // Check if selected file was removed
              if (event.type.toString() == 'remove' &&
                  event.path == _fileInfo['path']) {
                if (!Server().fileExists(_fileInfo['path'])) {
                  setFileStatus(false);
                }
              }
            });
          } on FileSystemException {
            setFileStatus(false);
          } catch (_) {
            setFileStatus(false);
          }

          // Import layout
          return Column(
            children: <Widget>[
              Card(
                color: const Color.fromRGBO(34, 34, 34, 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: QrImage(
                    data: _hostName,
                    version: QrVersions.auto,
                    size: (MediaQuery.of(context).size.height * .23),
                    backgroundColor: const Color.fromRGBO(255, 255, 255, 1.0),
                    padding: EdgeInsets.all(
                        (MediaQuery.of(context).size.height * .029)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 330,
                ),
                child: Card(
                  color: const Color.fromRGBO(34, 34, 34, 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  elevation: 1,
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: <Widget>[
                        Table(
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          columnWidths: {
                            0: const FlexColumnWidth(15),
                            1: const FlexColumnWidth(0.5),
                            2: const FlexColumnWidth(3.8),
                          },
                          children: [
                            TableRow(
                              children: [
                                Card(
                                  color: const Color.fromRGBO(42, 42, 42, 1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  elevation: 2,
                                  child: Container(
                                    padding:
                                        const EdgeInsets.fromLTRB(16, 0, 16, 0),
                                    child: ButtonTheme(
                                      alignedDropdown: true,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(15.0),
                                      ),
                                      child: DropdownButton<String>(
                                        dropdownColor:
                                            const Color.fromRGBO(58, 58, 58, 1),
                                        value: selectedIP,
                                        isExpanded: true,
                                        elevation: 4,
                                        underline: const SizedBox(),
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            selectedIP = newValue;
                                          });
                                        },
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText2,
                                        items: snapshot.data!['interfaces']
                                            .map<DropdownMenuItem<String>>(
                                                (String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Center(
                                              child: Text(value),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                SizedBox(
                                  height: 48,
                                  width: 48,
                                  child: TextButton(
                                    style: ButtonStyle(
                                      overlayColor: MaterialStateProperty
                                          .resolveWith<Color>(
                                              (Set<MaterialState> states) {
                                        if (states
                                            .contains(MaterialState.focused)) {
                                          return Colors.white12;
                                        }
                                        if (states
                                            .contains(MaterialState.hovered)) {
                                          return Colors.white24;
                                        }
                                        if (states
                                            .contains(MaterialState.pressed)) {
                                          return Colors.white30;
                                        }
                                        return Colors.white30;
                                      }),
                                      shape: MaterialStateProperty.all(
                                        RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10.0),
                                        ),
                                      ),
                                      backgroundColor:
                                          MaterialStateProperty.all(
                                        const Color.fromRGBO(42, 42, 42, 1),
                                      ),
                                      elevation: MaterialStateProperty.all(2),
                                    ),
                                    onPressed: () {
                                      ShareManager().share(_hostName, context);
                                    },
                                    onLongPress: () {
                                      !fileInPath
                                          ? showToast(AppLocalizations.of(
                                                  context)!
                                              .page_imported_fileinpath_enabled)
                                          : showToast(AppLocalizations.of(
                                                  context)!
                                              .page_imported_fileinpath_disabled);
                                      setState(() {
                                        fileInPath = !fileInPath;
                                      });
                                    },
                                    child: Icon(
                                      !isDesktop ? Icons.share : Icons.copy,
                                      size: 17,
                                      color: const Color.fromRGBO(
                                          255, 255, 255, 1.0),
                                      semanticLabel: !isDesktop
                                          ? AppLocalizations.of(context)!
                                              .page_imported_share_sheet_label
                                          : AppLocalizations.of(context)!
                                              .page_imported_share_clipboard_label,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Table(
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          columnWidths: {
                            0: const FlexColumnWidth(2.3),
                            1: const FlexColumnWidth(4),
                          },
                          children: [
                            TableRow(
                              children: [
                                Container(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Center(
                                    child: Text(
                                      AppLocalizations.of(context)!
                                          .page_imported_file,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Tooltip(
                                    message: !isDesktop
                                        ? _fileInfo['name']
                                        : _fileInfo['path'],
                                    showDuration: const Duration(seconds: 5),
                                    padding: const EdgeInsets.all(10),
                                    textStyle: const TextStyle(
                                      color: const Color.fromRGBO(0, 0, 0, 1.0),
                                    ),
                                    child: Center(
                                      child: AutoSizeText(
                                        _fileInfo['name'],
                                        style: const TextStyle(fontSize: 13),
                                        minFontSize: 11,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                Container(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Center(
                                    child: Text(
                                      AppLocalizations.of(context)!
                                          .page_imported_size,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Center(
                                    child: Text(
                                      _sizeHuman,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                Container(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Center(
                                    child: Text(
                                      AppLocalizations.of(context)!
                                          .page_imported_port,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Center(
                                    child: Text(
                                      snapshot.data!['port'].toString(),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          return loadingPage();
        }
      },
    );
  }
}
