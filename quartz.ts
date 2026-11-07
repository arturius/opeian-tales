import { loadQuartzConfig, loadQuartzLayout } from "./quartz/plugins/loader/config-loader"

const config = await loadQuartzConfig()

// Site password: the encrypted-pages plugin remembers a correct password only in
// sessionStorage (one tab, until it's closed). This script runs in <head> on every page,
// before the plugin, and mirrors that entry to localStorage, so players enter the password
// once per browser and every page and tab unlocks after that.
const PASSWORD_KEY = "encrypted-pages-passwords"
config.plugins.transformers.push({
  name: "RememberSitePassword",
  externalResources: () => ({
    js: [
      {
        loadTime: "beforeDOMReady",
        contentType: "inline",
        script: `(() => {
  const key = ${JSON.stringify(PASSWORD_KEY)}
  try {
    const saved = localStorage.getItem(key)
    if (saved && !sessionStorage.getItem(key)) sessionStorage.setItem(key, saved)
    const setItem = Storage.prototype.setItem
    Storage.prototype.setItem = function (k, v) {
      setItem.call(this, k, v)
      if (this === sessionStorage && k === key) {
        try { setItem.call(localStorage, k, v) } catch {}
      }
    }
  } catch {}
})()`,
      },
    ],
  }),
})

export default config
export const layout = await loadQuartzLayout()
