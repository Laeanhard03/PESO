from playwright.sync_api import sync_playwright

URL='http://127.0.0.1:5173/'
choices=[
    ('Highest education','Senior High School','career-education-selected'),
    ('Work experience status','No previous work experience','career-experience-selected'),
    ('Skills stage','New entrant / still learning','career-skills-selected'),
]

with sync_playwright() as p:
    browser=p.chromium.launch(headless=True, executable_path=r'C:\Program Files\Google\Chrome\Application\chrome.exe')
    for width in (1260,510,390):
        page=browser.new_page(viewport={'width':width,'height':780})
        errors=[]
        page.on('pageerror',lambda error:errors.append(str(error)))
        page.goto(URL,wait_until='domcontentloaded')
        page.get_by_label('Highest education').wait_for()
        page.get_by_role('button',name='Download Form & Continue').click()
        page.get_by_test_id('applicant-missing').wait_for()
        for label, value, output in choices:
            field=page.get_by_label(label)
            field.focus()
            field.press('Home')
            for _ in range(16):
                if field.input_value()==value:
                    break
                field.press('ArrowDown')
            field.press('Enter')
            page.wait_for_timeout(100)
            assert field.input_value()==value,(width,label,field.input_value())
            assert page.get_by_test_id(output).inner_text()==f'Selected: {value}',(width,label)
            assert field.get_attribute('data-validation-error') is None,(width,label,'validation not cleared')
            print('PASS',width,label,value,flush=True)
        assert not errors,(width,errors)
        page.close()
    browser.close()
    print('PASS all three native career dropdowns at desktop, tablet, and mobile widths',flush=True)
