import { chromium } from 'playwright';

(async () => {
    console.log('Launching browser...');
    const browser = await chromium.launch();
    const context = await browser.newContext({
        httpCredentials: {
            username: 'danxon',
            password: '2379126x'
        }
    });
    const page = await context.newPage();

    console.log('Navigating to OpenCode...');
    try {
        await page.goto('http://43.255.122.29:19898/', { waitUntil: 'load', timeout: 60000 });
    } catch (e) {
        if (e.message.includes('Download is starting')) {
            console.log('Warning: Download started. Ignoring and waiting...');
            await page.waitForTimeout(5000);
        } else {
            throw e;
        }
    }

    console.log('Successfully navigated. Waiting for dashboard to fully render...');
    await page.waitForTimeout(5000);
    await page.screenshot({ path: 'dashboard.png', fullPage: true });
    console.log('Dashboard screenshot saved as dashboard.png');

    await browser.close();
    console.log('Done.');
})();
