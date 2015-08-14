(function () {
  var fpsDiv;
  var loading = true;
  var index = 0;
  var startTime = +new Date();

  var image = document.createElement('img');
  image.src = '/image';
  image.onload = function() {
    loading = false;
    ++index;
    updateImage();
  }
  document.body.appendChild(image);

  function updateImage() {
    if (!loading) {
      image.src = '/image?n=' + index;
      loading = true;
    }
    fpsDiv.innerHTML = index * 1000 / (+new Date() - startTime);
  }

  fpsDiv = document.createElement('div');
  fpsDiv.style.position = 'absolute';
  fpsDiv.style.overflow = 'hidden';
  fpsDiv.style.left = '10px';
  fpsDiv.style.top = '10px';
  fpsDiv.style.left = '10px';
  fpsDiv.style.width = '60px';
  fpsDiv.style.height = '30px';
  fpsDiv.style.backgroundColor = 'white';
  document.body.appendChild(fpsDiv);

})();
