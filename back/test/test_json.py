import requests

token = "832961e35dd33f1e7315f6f4b62896bfae9bc25714853b1e1415e9b72d83da07"

response = requests.get(
    "http://localhost:5000/api/cart/items",
    headers={
        "Authorization": token
    }
)

print("STATUS:", response.status_code)
print("JSON:", response.json())
