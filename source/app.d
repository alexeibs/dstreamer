import core.sys.windows.windows;

import derelict.freeimage.freeimage;

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

__gshared ubyte[] testImage;

void getIndex(HTTPServerRequest request, HTTPServerResponse response) {
  response.render!("index.dt", request);
}

void getImage(HTTPServerRequest request, HTTPServerResponse response) {
  response.contentType = "image/jpeg";
  response.bodyWriter.write(testImage);
}

void takeScreenshots() {
  int screenWidth = GetSystemMetrics(SM_CXSCREEN);
  int screenHeight = GetSystemMetrics(SM_CYSCREEN);

  HDC hdcScreen = GetDC(null);
  HDC hdcBuffer = CreateCompatibleDC(hdcScreen);
  HBITMAP hBitmap = CreateCompatibleBitmap(hdcScreen, screenWidth, screenHeight);
  auto hOldGdiObject = SelectObject(hdcBuffer, hBitmap);
  BitBlt(hdcBuffer, 0, 0, screenWidth, screenHeight, hdcScreen, 0, 0, cast(DWORD)0x00CC0020 /*SRCCOPY*/);

  BITMAP winBitmap;
  GetObjectA(hBitmap, BITMAP.sizeof, cast(LPVOID)&winBitmap);

  FreeImage_Initialise();

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
  FreeImage_Save(FIF_JPEG, bitmap24, "test.jpg", JPEG_QUALITYSUPERB | JPEG_OPTIMIZE);

  FreeImage_Unload(bitmap24);
  FreeImage_Unload(fiBitmap);
  FreeImage_DeInitialise();
}

shared static this() {
  DerelictFI.load();
  takeScreenshots();

  testImage = cast(ubyte[]) std.file.read("test.jpg");

  auto router = new URLRouter;
  router.get("/", &getIndex);
  router.get("/image", &getImage);
  router.get("*", serveStaticFiles("./public/"));

  auto settings = new HTTPServerSettings;
  settings.port = 8080;
  listenHTTP(settings, router);
}
