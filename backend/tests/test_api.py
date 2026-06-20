import unittest

from fastapi.testclient import TestClient

from main import app


class ApiTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def test_health_includes_server_ip_in_body_and_header(self):
        response = self.client.get("/health")

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertIn("serverIp", body)
        self.assertTrue(body["serverIp"])
        self.assertEqual(
            response.headers["x-wareeny-server-ip"],
            body["serverIp"],
        )

    def test_app_config_includes_server_ip(self):
        response = self.client.get("/app-config")

        self.assertEqual(response.status_code, 200)
        self.assertIn("serverIp", response.json())


if __name__ == "__main__":
    unittest.main()
