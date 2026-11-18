from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch()
    d = b.new_page(viewport={"width": 1440, "height": 1000})
    errs = []
    d.on("pageerror", lambda e: errs.append(str(e)))
    d.goto("http://localhost:8090", wait_until="networkidle", timeout=45000)
    d.wait_for_timeout(1200)
    d.screenshot(path="ref-home.png")
    print("errors:", errs)
    print("script visible:", d.eval_on_selector(".hero-script", "e=>getComputedStyle(e).display"))
    print("h1 size:", d.eval_on_selector(".hero h1", "e=>getComputedStyle(e).fontSize"))
    b.close()
