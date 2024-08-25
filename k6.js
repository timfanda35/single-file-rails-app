import http from "k6/http";

export let options = {
    vus: 200,
    rps: 80,
    duration: "30s",
};

export default function () {
    http.get("http://127.0.0.1:3000");
}
