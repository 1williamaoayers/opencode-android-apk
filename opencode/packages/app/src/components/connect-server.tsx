
import { createStore } from "solid-js/store"
import { createSignal, Show } from "solid-js"
import { Button } from "@opencode-ai/ui/button"
import { TextField } from "@opencode-ai/ui/text-field"
import { normalizeServerUrl, useServer } from "@/context/server"
import { usePlatform } from "@/context/platform"
import { checkServerHealth } from "@/utils/server-health"
import { useLanguage } from "@/context/language"
import { showToast } from "@opencode-ai/ui/toast"

export function ConnectServer() {
    const server = useServer()
    const platform = usePlatform()
    const language = useLanguage()
    const fetcher = platform.fetch ?? globalThis.fetch

    const [url, setUrl] = createSignal("")
    const [busy, setBusy] = createSignal(false)
    const [error, setError] = createSignal("")

    async function connect() {
        if (busy()) return
        setError("")

        const input = url().trim()
        if (!input) {
            setError("Please enter a URL")
            return
        }

        const normalized = normalizeServerUrl(input)
        if (!normalized) {
            setError("Invalid URL format")
            return
        }

        setBusy(true)
        try {
            const result = await checkServerHealth(normalized, fetcher)
            if (!result.healthy) {
                setError("Could not connect to server")
                return
            }

            // If successful, set as default and active
            if (platform.setDefaultServerUrl) {
                try {
                    await platform.setDefaultServerUrl(normalized)
                } catch (e) {
                    console.error("Failed to save default server url", e)
                }
            }

            server.add(normalized)
            server.setActive(normalized)

        } catch (e) {
            setError(e instanceof Error ? e.message : String(e))
        } finally {
            setBusy(false)
        }
    }

    const handleKey = (e: KeyboardEvent) => {
        if (e.key === "Enter") {
            connect()
        }
    }

    return (
        <div class="flex flex-col items-center justify-center min-h-screen bg-surface-base p-4">
            <div class="w-full max-w-md p-6 rounded-lg bg-surface-raised-base border border-border-base shadow-sm">
                <h1 class="text-xl font-bold mb-4 text-text-strong">Connect to Server</h1>

                <p class="mb-4 text-text-weak text-sm">
                    Enter the URL of your OpenCode server to begin.
                </p>

                <div class="flex flex-col gap-4">
                    <TextField
                        placeholder="https://your-opencode-server.com"
                        value={url()}
                        onChange={setUrl}
                        onKeyDown={handleKey}
                        error={error()}
                        disabled={busy()}
                        class="w-full"
                    />

                    <Button
                        onClick={connect}
                        disabled={busy()}
                        class="w-full justify-center"
                    >
                        {busy() ? "Connecting..." : "Connect"}
                    </Button>

                    <Show when={error()}>
                        <p class="text-icon-critical-base text-sm mt-2">{error()}</p>
                    </Show>
                </div>
            </div>
        </div>
    )
}
