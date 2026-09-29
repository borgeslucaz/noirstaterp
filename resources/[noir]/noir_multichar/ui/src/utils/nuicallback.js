

import { browserNuiCallback, isBrowserDevelopment } from "./browserDevelopment";

export async function nuicallback(eventName, data) {
  if (isBrowserDevelopment()) {
    return browserNuiCallback(eventName, data);
  }

  const options = {
    method: "post",
    headers: {
      "Content-Type": "application/json; charset=UTF-8"
    },
    body: JSON.stringify(data)
  }



  const resourceName = window.GetParentResourceName
    ? window.GetParentResourceName()
    : "nui-frame-app"

  const resp = await fetch(`https://${resourceName}/${eventName}`, options)

  const respFormatted = await resp.json()

  return respFormatted
}