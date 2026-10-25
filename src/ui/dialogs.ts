export interface DialogAction<T> {
  label: string;
  value: T;
  kind?: "primary" | "danger";
}

export interface DialogOptions<T> {
  title: string;
  body?: Node | string;
  actions: DialogAction<T>[];
  /** Value returned when the dialog is dismissed (Esc). */
  dismissValue: T;
  className?: string;
}

/** Shows a modal <dialog> and resolves with the value of the button pressed. */
export function showDialog<T>(options: DialogOptions<T>): Promise<T> {
  const dialog = document.createElement("dialog");
  dialog.className = `dialog ${options.className ?? ""}`;
  const title = document.createElement("h2");
  title.textContent = options.title;
  dialog.append(title);
  if (options.body !== undefined) {
    const body = document.createElement("div");
    body.className = "dialog-body";
    body.append(options.body);
    dialog.append(body);
  }
  const actions = document.createElement("div");
  actions.className = "dialog-actions";
  dialog.append(actions);
  document.body.append(dialog);

  return new Promise<T>((resolve) => {
    let value = options.dismissValue;
    for (const action of options.actions) {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = action.label;
      if (action.kind) button.classList.add(action.kind);
      button.addEventListener("click", () => {
        value = action.value;
        dialog.close();
      });
      actions.append(button);
    }
    dialog.addEventListener("close", () => {
      dialog.remove();
      resolve(value);
    });
    dialog.showModal();
  });
}

export function element<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  attributes: Record<string, string> = {},
  ...children: (Node | string)[]
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  for (const [name, value] of Object.entries(attributes)) {
    if (name === "class") node.className = value;
    else node.setAttribute(name, value);
  }
  node.append(...children);
  return node;
}
