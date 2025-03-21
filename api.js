async function callApi(endpoint, method = 'GET', body = null) {
    const idInstance = document.getElementById('idInstance').value;
    const apiToken = document.getElementById('apiToken').value;
    
    if (!idInstance || !apiToken) {
        alert("Введите idInstance и ApiTokenInstance!");
        return;
    }

    const url = `https://api.green-api.com/waInstance${idInstance}/${endpoint}/${apiToken}`;
    
    const options = { method };
    if (body) {
        options.headers = { 'Content-Type': 'application/json' };
        options.body = JSON.stringify(body);
    }

    try {
        const response = await fetch(url, options);
        const data = await response.json();
        document.getElementById('response').value = JSON.stringify(data, null, 2);
    } catch (error) {
        document.getElementById('response').value = `Ошибка: ${error.message}`;
    }
}

function getSettings() {
    callApi('getSettings');
}

function getStateInstance() {
    callApi('getStateInstance');
}

function sendMessage() {
    const phoneNumber = document.getElementById('phoneNumber').value;
    const messageText = document.getElementById('messageText').value;
    
    if (!phoneNumber || !messageText) {
        alert("Введите номер и текст сообщения!");
        return;
    }

    callApi('sendMessage', 'POST', {
        chatId: `${phoneNumber}@c.us`,
        message: messageText
    });
}
