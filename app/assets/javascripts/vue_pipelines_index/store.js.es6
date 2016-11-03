/* global gl, Flash */
/* eslint-disable no-param-reassign */

((gl) => {
  const api = '/api/v3/projects';
  const paginate = '?per_page=5&page=';

  gl.PipelineStore = class {
    fetchDataLoop(Vue, pageNum) {
      const goFetch = () =>
        this.$http.get(`${api}/${this.scope}/pipelines${paginate}${pageNum}`)
          .then((response) => {
            Vue.set(this, 'pipelines', JSON.parse(response.body));
          }, () => new Flash(
            'Something went wrong on our end.'
          ));

      // inital fetch and then start timeout loop
      goFetch();

      // eventually clearInterval(this.intervalId)
      this.intervalId = setInterval(() => {
        goFetch();
      }, 60000);
    }
  };
})(window.gl || (window.gl = {}));
