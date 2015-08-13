import vibe.http.fileserver;
import vibe.http.router : URLRouter;
import vibe.http.server;

__gshared ubyte[] testImage;

void getIndex(HTTPServerRequest request, HTTPServerResponse response) {
  response.render!("index.dt", request);
}

void getImage(HTTPServerRequest request, HTTPServerResponse response) {
  response.contentType = "image/jpeg";
  response.bodyWriter.write(testImage);
}

shared static this() {
  testImage = cast(ubyte[]) std.file.read("test.jpg");

  auto router = new URLRouter;
  router.get("/", &getIndex);
  router.get("/image", &getImage);
  router.get("*", serveStaticFiles("./public/"));

  auto settings = new HTTPServerSettings;
  settings.port = 8080;
  listenHTTP(settings, router);
}
