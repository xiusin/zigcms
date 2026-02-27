<script>
  import { ref, h, onMounted, onUnmounted, createApp } from 'vue';

  export default {
    name: 'ParseNode',
    props: {
      vnode: {
        type: [Object, String, Number],
        required: true,
      },
    },
    setup(props, { emit }) {
      const container = ref(null);
      let app = null;

      const renderApp = () => {
        app = props.vnode
          ? createApp({
              render() {
                return props.vnode;
              },
            })
          : null;
        if (app) {
          app.mount(container.value);
        }
      };

      const destroyApp = () => {
        if (app) {
          app.unmount();
          app = null;
        }
      };

      onUnmounted(() => {
        destroyApp();
      });

      onMounted(() => {
        renderApp();
      });

      return {
        container,
      };
    },

    render() {
      return h('div', { ref: 'container' });
    },
  };
</script>
