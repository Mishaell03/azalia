import requests

token = "567a24c417df7b3fc3b886f6fd42c124cc30d0ace073c4a60e5c8fd577ea8c23"

headers = {
    "Authorization": token,
    "Content-Type": "application/json"
}

def call(path, method='get', json_data=None):
    url = f"http://localhost:5000{path}"
    try:
        if method == 'get':
            r = requests.get(url, headers=headers, timeout=5)
        else:
            r = requests.post(url, headers=headers, json=json_data, timeout=5)
        print(f"=== {method.upper()} {url} ===")
        print('Status:', r.status_code)
        try:
            print('JSON:', r.json())
        except Exception:
            print('Text:', r.text)
    except Exception as e:
        print(f'Error calling {url}:', e)


def main():
    # Debug whoami to see which user соответствует токену
    call('/api/debug/whoami')

    # Check users (admin-only)
    call('/api/users')

    # Check employees list
    call('/api/employees')

    # Check single employee (id=1)
    call('/api/employees/1')

    # Try assign (will likely fail without proper data/permissions)
    assign_payload = {
        'telegram_id': 123456,
        'position_id': 1,
        'salary': 50000,
    }
    
    deactivation_payload = {
        'telegram_id': 123456,
        "is_active": False, 
    }
    # call('/api/employees/assign', method='post', json_data=assign_payload)

    # Try deactivation/activation employee
    # if need activation true and same api
    call('/api/employees/deactivate', method='post', json_data=deactivation_payload)


if __name__ == '__main__':
    main()
