/*
 * WebFlashServer.ino
 *
 * Created: 8/27/2017 12:44:09 AM
 * Author: treii28@hotmail.com
 */

#ifndef Arduino_h
#include <Arduino.h>
#endif

#ifndef ESP8266WEBSERVER_H
#include <ESP8266WebServer.h>
#endif

#ifndef WiFi_h
#include <ESP8266WiFi.h>
#endif
#ifndef WiFi_h
#include <ESP8266WiFi.h>
#endif
#ifndef wificlient_h
#include <WiFiClient.h>
#endif
#ifndef IPAddress_h
#include <IPAddress.h>
#endif

#ifndef WEBFILES_H_
#include "webfiles.h"
#endif

ESP8266WebServer APWebServer;
IPAddress myIP;

int findFlashIndexByPath(String path) {
	int NumFiles = sizeof(files) / sizeof(struct t_websitefiles);
	for (int i = 0; i < NumFiles; i++) {
		if (path == files[i].path)
		return i;
	}
	return -1;
}

bool loadIndexFromFlash(int i) {
	if (i >= 0) {
		_FLASH_ARRAY<uint8_t>* filecontent;
		String dataType = "text/plain";
		unsigned int len = 0;

		dataType = String(files[i].mime);
		len = files[i].len;
		if (files[i].enc != "")
			APWebServer.sendHeader("Content-Encoding", files[i].enc);
		APWebServer.setContentLength(len);
		APWebServer.send(200, files[i].mime, "");

		filecontent = (_FLASH_ARRAY<uint8_t>*)files[i].content;
		filecontent->open();
		WiFiClient APclient = APWebServer.client();
		APclient.write(*filecontent, 100);
		return true;
	}
	return false;
}

/* Flash.h load functions for web contet */
bool loadPathFromFlash(String path) {
	if (path.endsWith("/")) path += "index.htm";

	int NumFiles = sizeof(files) / sizeof(struct t_websitefiles);
	int index = findFlashIndexByPath(path);
	if (index >= 0) {
		Serial.print("serving content for path: ");
		Serial.println(path);
		return loadIndexFromFlash(index);
	} else {
		return false;
	}
}

void handleNotFound() {
	// try to find the file in the flash
	if (loadPathFromFlash(APWebServer.uri())) return;

	String message = "File Not Found\n\n";
	message += "URI..........: ";
	message += APWebServer.uri();
	message += "\nMethod.....: ";
	message += (APWebServer.method() == HTTP_GET) ? "GET" : "POST";
	message += "\nArguments..: ";
	message += APWebServer.args();
	message += "\n";
	for (uint8_t i = 0; i < APWebServer.args(); i++) {
		message += " " + APWebServer.argName(i) + ": " + APWebServer.arg(i) + "\n";
	}
	message += "\n";
	message += "FreeHeap.....: " + String(ESP.getFreeHeap()) + "\n";
	message += "ChipID.......: " + String(ESP.getChipId()) + "\n";
	message += "FlashChipId..: " + String(ESP.getFlashChipId()) + "\n";
	message += "FlashChipSize: " + String(ESP.getFlashChipSize()) + " bytes\n";
	message += "getCycleCount: " + String(ESP.getCycleCount()) + " Cycles\n";
	message += "Milliseconds.: " + String(millis()) + " Milliseconds\n";
	APWebServer.send(404, "text/plain", message);
}

void handleAPClient()
{
	APWebServer.handleClient();
}

/* access point setup */
void setupAP() {
	String apSSID = "WebFlashServer";
	Serial.println(apSSID);

	String apPass = "knock knock knock";
	/* You can remove the password parameter if you want the AP to be open. */
	WiFi.mode(WIFI_AP_STA); // set both AP and STA modes
	WiFi.softAP(apSSID.c_str(), apPass.c_str());
	myIP = WiFi.softAPIP();

	Serial.println("AP IP address: ");
	Serial.println(myIP);
}

void setupServer() {
	APWebServer = ESP8266WebServer(80);
	APWebServer.onNotFound(handleNotFound);
	APWebServer.begin();
	Serial.println("HTTP server started");
}

/* default arduino methods */

void setup() {
	Serial.begin(115200);
	Serial.println();
	delay(500);

	setupAP();
	setupServer();
}

void loop() {
	for (int t = 0; t < 500; t++) {
		APWebServer.handleClient();
		delay(50);
	}
}
