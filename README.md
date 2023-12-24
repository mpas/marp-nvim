# 🔌 Marp.nvim
A [neovim](https://neovim.io/) plugin for [Marp](https://marp.app/).

## ✨ Features
- start/stop the Marp server
- see if Marp server is running
- browser window opens when Marp is running and ready

## ⚡️ Requirements

- [Marp](https://marp.app/) CLI installed and available in your path
## 📦 Installation

Install the plugin with your preferred package manager:

## ⚙️ Configuration

The following defaults are provided:

```lua
{
  port = 8080, -- the port on which the Marp server should listen
  wait_for_response_timeout = 30, -- how long to wait for a response from the server before giving up
  wait_for_response_delay = 1, -- how long to wait between attempts to connect to the server
}
```

In the above example, the Marp server will be started on port 8080, and the plugin will wait for up to 30 seconds for a response from the server before giving up. It will try to connect to the server every second.
