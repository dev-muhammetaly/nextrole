{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({onEntrypointLoaded: async function(initializer) {
  try {
    const runner = await initializer.initializeEngine();
    await runner.runApp();
    document.getElementById('app-loading')?.remove();
  } catch (_) {
    const loading = document.getElementById('app-loading');
    if (loading) loading.innerHTML = '<h1>We couldn’t start the app.</h1><p>Please refresh or try another browser.</p><a href="/">Back to Nextrole</a>';
  }
}});
