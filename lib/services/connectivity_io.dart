import 'dart:io';

bool isIoConnectivityError(Object e) =>
    e is SocketException ||
    e is HandshakeException ||
    e is HttpException ||
    e is TlsException;
