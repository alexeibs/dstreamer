import core.sync.rwmutex;
import core.sys.windows.windows;

import derelict.freeimage.freeimage;

import vibe.core.log;
import vibe.http.fileserver;
import vibe.http.router : URLRouter;
import vibe.http.server;

extern (Windows) {
  export @nogc {
    HBITMAP CreateCompatibleBitmap(HDC hdc, INT nWidth, INT nHeight);
    BOOL BitBlt(HDC hdcDest, INT nXDest, INT nYDest, INT nWidth, INT nHeight, HDC hdcSrc, INT nXSrc, INT nYSrc, DWORD dwRop);
    INT GetDIBits(HDC hdc, HBITMAP hbmp, UINT uStartScan, UINT cScanLines, LPVOID lpvBits, derelict.freeimage.freeimage.PBITMAPINFO lpbi, UINT uUsage);
  }
}

alias Buffer = ubyte[];
__gshared Buffer[2] globalBuffers;
__gshared ReadWriteMutex bufferGuard;
__gshared int readBuffer = 0;
__gshared int writeBuffer = 1;

void takeScreenshot() {
  int screenWidth = GetSystemMetrics(SM_CXSCREEN);
  int screenHeight = GetSystemMetrics(SM_CYSCREEN);

  HDC hdcScreen = GetDC(null);
  HDC hdcBuffer = CreateCompatibleDC(hdcScreen);
  HBITMAP hBitmap = CreateCompatibleBitmap(hdcScreen, screenWidth, screenHeight);
  auto hOldGdiObject = SelectObject(hdcBuffer, hBitmap);
  BitBlt(hdcBuffer, 0, 0, screenWidth, screenHeight, hdcScreen, 0, 0, cast(DWORD)0x00CC0020 /*SRCCOPY*/);

  BITMAP winBitmap;
  GetObjectA(hBitmap, BITMAP.sizeof, cast(LPVOID)&winBitmap);


  auto fiBitmap = FreeImage_Allocate(winBitmap.bmWidth, winBitmap.bmHeight, winBitmap.bmBitsPixel);
  int nColors = FreeImage_GetColorsUsed(fiBitmap);
  GetDIBits(hdcBuffer, hBitmap, 0, FreeImage_GetHeight(fiBitmap), cast(LPVOID)FreeImage_GetBits(fiBitmap),
      FreeImage_GetInfo(fiBitmap), 0);

  FreeImage_GetInfoHeader(fiBitmap).biClrUsed = nColors;
  FreeImage_GetInfoHeader(fiBitmap).biClrImportant = nColors;

  SelectObject(hdcBuffer, hOldGdiObject);
  DeleteDC(hdcBuffer);
  DeleteDC(hdcScreen);

  auto bitmap24 = FreeImage_ConvertTo24Bits(fiBitmap);

  auto memoryStream = FreeImage_OpenMemory();
  FreeImage_SaveToMemory(FIF_JPEG, bitmap24, memoryStream, JPEG_QUALITYSUPERB | JPEG_OPTIMIZE);
  BYTE* data;
  DWORD size;
  FreeImage_AcquireMemory(memoryStream, &data, &size);

  globalBuffers[writeBuffer].length = size;
  for (uint i = 0; i < size; ++i) {
    globalBuffers[writeBuffer][i] = data[i];
  }

  FreeImage_CloseMemory(memoryStream);
  FreeImage_Unload(bitmap24);
  FreeImage_Unload(fiBitmap);
}

void screenshotThread() {
  DerelictFI.load();
  FreeImage_Initialise();
  while (true) {
    takeScreenshot();
    synchronized (bufferGuard.writer) {
      readBuffer = 1 - readBuffer;
      writeBuffer = 1 - writeBuffer;
    }
  }
}

void getIndex(HTTPServerRequest request, HTTPServerResponse response) {
  response.render!("index.dt", request);
}

void getImage(HTTPServerRequest request, HTTPServerResponse response) {
  response.contentType = "image/jpeg";
  synchronized (bufferGuard.reader) {
    response.bodyWriter.write(globalBuffers[readBuffer]);
  }
}

shared static this() {
  bufferGuard = new ReadWriteMutex(ReadWriteMutex.Policy.PREFER_WRITERS);
  new core.thread.Thread(&screenshotThread).start();

  auto router = new URLRouter;
  router.get("/", &getIndex);
  router.get("/image", &getImage);
  router.get("*", serveStaticFiles("./public/"));

  auto settings = new HTTPServerSettings;
  settings.port = 8080;
  listenHTTP(settings, router);
}
