defmodule IndrajaalWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for IndrajaalWeb.

  At the minimum, this module must provide:
  * `<.flash_group>` - renders flash messages
  * `<.error>` - renders form field errors

  The rest of this module should be used to define commonly used
  components throughout your application.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  use Gettext, backend: IndrajaalWeb.Gettext

  @doc """
  Renders a flash group component with flash messages.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :id,
       :string,
       default: "flash-group",
       doc: "the optional id of flash container"

  @spec flash_group(any()) :: any()
  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title="Success!" flash={@flash} />
      <.flash kind={:error} title="Error!" flash={@flash} />
      <.flash kind={:warning} title="Warning!" flash={@flash} />
    </div>
    """
  end

  @doc """
  Renders a single flash message.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :kind,
       :atom,
       values: [:info, :error, :warning],
       doc: "used for styling and flash lookup"

  attr :title, :string, default: nil

  attr :rest,
       :global,
       doc: "the arbitrary HTML attributes to add to the flash container"

  @spec flash(any()) :: any()
  def flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      id={@kind}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@kind}")}
      role="alert"
      class={
        [
          "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
          # L4-A08: Theme-aware flash messages (SC-HMI-008)
          @kind == :info &&
            "bg-emerald-50 dark:bg-emerald-900/50 text-emerald-800 dark:text-emerald-200 ring-emerald-500 fill-cyan-900 dark:fill-cyan-300",
          @kind == :error &&
            "bg-rose-50 dark:bg-rose-900/50 text-rose-900 dark:text-rose-200 shadow-md ring-rose-500 fill-rose-900 dark:fill-rose-300",
          @kind == :warning &&
            "bg-orange-50 dark:bg-orange-900/50 text-orange-800 dark:text-orange-200 ring-orange-500 fill-orange-900 dark:fill-orange-300"
        ]
      }
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :warning} name="hero-exclamation-triangle-mini" class="h-4 w-4" />
        {@title}
      </p>
      <p class="mt-2 text-sm leading-5">{msg}</p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard styling.
  """
  @spec show_flash(any(), any()) :: any()
  def show_flash(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  @doc """
  Hides the flash group with standard styling.
  """
  @spec hide_flash(any(), any()) :: any()
  def hide_flash(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Renders an icon.
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  @spec icon(any()) :: any()
  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  @spec hide(any(), any()) :: any()
  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  @spec translate_error({String.t(), keyword()}) :: String.t()
  def translate_error({msg, opts}) do
    # You can make use of gettext to translate error messages by
    # uncommenting and adjusting the following code:

    # if count = opts[:count] do
    #   Gettext.dngettext(IndrajaalWeb.Gettext, "errors", msg, msg, count, opts)
    # else
    #   Gettext.dgettext(IndrajaalWeb.Gettext, "errors", msg, opts)
    # end

    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  @spec translate_errors(any(), any()) :: any()
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Renders a generic error.
  """
  attr :errors, :list, default: []
  slot :inner_block

  @spec error(any()) :: any()
  def error(assigns) do
    ~H"""
    <span class="mt-3 flex gap-3 text-sm leading-6 text-rose-600 dark:text-rose-400">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      <span :if={@inner_block}>{render_slot(@inner_block)}</span>
      <span :if={!@inner_block}>{Enum.join(@errors, ", ")}</span>
    </span>
    """
  end

  @doc """
  Renders a button component.
  """
  attr :type, :string, default: "button"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-id phx-submit phx-disable-with)
  slot :inner_block, required: true

  @spec button(term()) :: term()
  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={
        [
          # L4-A08: Theme-aware button
          "phx-submit-loading:opacity-75 rounded-lg py-2 px-3",
          "bg-zinc-900 dark:bg-zinc-100 hover:bg-zinc-700 dark:hover:bg-zinc-300",
          "text-sm font-semibold leading-6 text-white dark:text-zinc-900 active:text-white/80 dark:active:text-zinc-900/80",
          @class
        ]
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders an input field.
  """
  attr :field, Phoenix.HTML.FormField
  attr :label, :string
  attr :type, :string, default: "text"
  attr :required, :boolean, default: false
  attr :name, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :options, :list, default: []
  attr :prompt, :string, default: nil
  attr :checked, :boolean, default: false
  attr :rest, :global, include: ~w(phx-keyup phx-debounce phx-change)

  @spec input(term()) :: term()
  def input(assigns) do
    ~H"""
    <div>
      <.label :if={@label} for={@field.id}>{@label}</.label>
      <input
        id={@field.id}
        name={@field.name}
        value={@field.value}
        type={@type}
        required={@required}
        class="mt-2 block w-full rounded-lg border-zinc-300 dark:border-zinc-600 bg-white dark:bg-zinc-800 text-zinc-900 dark:text-zinc-100 py-[7px] px-[11px] text-sm"
        {@rest}
      />
      <.error :for={msg <- @field.errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders a simple form.
  """
  attr :for, :any, required: true
  attr :rest, :global, include: ~w(phx-submit phx-change)
  slot :inner_block, required: true
  slot :actions, doc: "Form action buttons"

  @spec simple_form(term()) :: term()
  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} {@rest}>
      {render_slot(@inner_block, f)}
    </.form>
    """
  end

  @doc """
  Renders a modal component.
  """
  attr :id, :string, required: true
  attr :on_cancel, JS, default: %JS{}
  attr :rest, :global
  slot :inner_block, required: true

  @spec modal(term()) :: term()
  def modal(assigns) do
    ~H"""
    <div id={@id} class="fixed inset-0 z-50" {@rest}>
      <div class="fixed inset-0 bg-black/50" phx-click={@on_cancel}></div>
      <div class="fixed inset-0 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="w-full max-w-md transform overflow-hidden rounded-2xl bg-white dark:bg-zinc-800 p-6 shadow-xl">
            {render_slot(@inner_block)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  @spec label(term()) :: term()
  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-medium leading-6 text-zinc-800 dark:text-zinc-200">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Renders a form wrapper component.
  """
  attr :for, :any, required: true
  attr :rest, :global
  slot :inner_block, required: true

  @spec form_wrapper(term()) :: term()
  def form_wrapper(assigns) do
    ~H"""
    <Phoenix.Component.form :let={f} for={@for} {@rest}>
      {render_slot(@inner_block, f)}
    </Phoenix.Component.form>
    """
  end

  @doc """
  Renders a card component with optional header and content.
  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true
  slot :header, doc: "Card header content"
  slot :body, doc: "Card body content"
  slot :actions, doc: "Card action buttons"

  @spec card(term()) :: term()
  def card(assigns) do
    ~H"""
    <div class={["bg-white shadow-sm border border-gray-200 rounded-lg", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a header component with title and optional actions.
  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true
  slot :subtitle, doc: "Header subtitle content"
  slot :actions, doc: "Header action buttons"

  @spec header(term()) :: term()
  def header(assigns) do
    ~H"""
    <header
      class={[
        "flex items-center justify-between py-4 px-6 bg-white border-b border-gray-200",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </header>
    """
  end

  @doc """
  Renders an icon button component.
  """
  attr :class, :string, default: nil
  attr :type, :string, default: "button"
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(phx-click phx-value-id phx-value-user-id phx-value-role-id)
  slot :inner_block, required: true

  @spec icon_button(term()) :: term()
  def icon_button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class={[
        "inline-flex items-center justify-center p-2 text-gray-600 hover:text-gray-800 hover:bg-gray-100 rounded-md transition-colors",
        @disabled && "opacity-50 cursor-not-allowed",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
end
