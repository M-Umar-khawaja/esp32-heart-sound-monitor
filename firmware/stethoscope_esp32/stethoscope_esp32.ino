/*
  Digital Stethoscope - ESP32 acquisition firmware  v1.1
  ----------------------------------------------------------------------------
  Board   : ESP32-WROOM-32 DevKit, 30-pin   (Arduino IDE board: "ESP32 Dev Module")
  Wiring  : GY-MAX4466 VCC -> ESP32 3V3        (NEVER 5V / VIN)
            GY-MAX4466 GND -> ESP32 GND
            GY-MAX4466 OUT -> R1 1k -> ESP32 GPIO34 (D34, ADC1_CH6)
            C1 100 nF from GPIO34 to GND
  Output  : USB serial, 921600 baud, 8N1, lines end with '\n'
            RAW mode (default): one ADC value 0-4095 per line, 4000 lines/s.
            Silence sits near the middle (about 1.65 V).
            Lines that start with '#' are status text, not samples.
  Commands: type one letter in Serial Monitor (or send it from MATLAB)
            r = stream raw samples at 4000 Hz (default at power-up)
            v = view mode for Arduino Serial Plotter (heartbeat envelope, 25 Hz)
            s = stop streaming
            c = check wiring and gain (1 s measurement, prints a verdict)
            i = print settings
*/

#include <Arduino.h>

// ----------------------------- settings -------------------------------------
const uint8_t  MIC_PIN        = 34;               // D34 / GPIO34 / ADC1_CH6 (input-only pin)
const uint8_t  LED_PIN        = 2;                // on-board blue LED: ON while streaming
const uint32_t BAUD           = 921600;           // if your board shows garbage, use 460800
const uint32_t FS_HZ          = 4000;             // output sample rate (samples per second)
const uint8_t  MAX_OVERSAMPLE = 4;                // ADC reads averaged per output sample
const uint32_t PERIOD_US      = 1000000UL / FS_HZ; // 250 us between samples
const uint16_t VIEW_DECIMATE  = FS_HZ / 25;       // view mode: one point per 40 ms

// ----------------------------- state ----------------------------------------
enum StethMode : uint8_t { SM_STOP, SM_RAW, SM_VIEW };
StethMode mode      = SM_RAW;
uint8_t  oversample = 1;      // chosen at start-up from the measured ADC speed
uint32_t readTimeUs = 0;      // measured time of one analogRead()
uint32_t nextTick   = 0;      // micros() time of the next sample
uint32_t resyncs    = 0;      // times the sampler fell far behind and restarted
int32_t  biasQ8     = 2048L << 8;  // running average of the signal (x256)
uint16_t viewCount  = 0;
uint16_t viewPeak   = 0;

// ----------------------------- helpers --------------------------------------
static inline uint16_t readSample() {
  uint32_t sum = 0;
  for (uint8_t k = 0; k < oversample; k++) sum += analogRead(MIC_PIN);
  return (uint16_t)(sum / oversample);
}

// Fast integer-to-text: "0".."4095" followed by '\n'
static inline void sendNumber(uint16_t v) {
  char buf[6];
  uint8_t n = 0;
  if (v >= 1000) buf[n++] = '0' + (v / 1000);
  if (v >= 100)  buf[n++] = '0' + (v / 100) % 10;
  if (v >= 10)   buf[n++] = '0' + (v / 10) % 10;
  buf[n++] = '0' + (v % 10);
  buf[n++] = '\n';
  Serial.write((const uint8_t *)buf, n);
}

void setMode(uint8_t m) {   // takes uint8_t so Arduino's auto-prototypes compile
  mode = (StethMode)m;
  digitalWrite(LED_PIN, m == SM_STOP ? LOW : HIGH);
  viewCount = 0;
  viewPeak  = 0;
  nextTick  = micros();
}

void printInfo() {
  Serial.println();
  Serial.println(F("# Digital Stethoscope ESP32 firmware v1.1"));
  Serial.printf("# input GPIO%u (ADC1_CH6), 12-bit, 11 dB attenuation\n", MIC_PIN);
  Serial.printf("# sample rate %lu Hz, baud %lu\n", (unsigned long)FS_HZ, (unsigned long)BAUD);
  Serial.printf("# analogRead %lu us, averaging %u reads per sample, resyncs %lu\n",
                (unsigned long)readTimeUs, oversample, (unsigned long)resyncs);
  Serial.println(F("# commands: r=raw 4 kHz  v=plotter view  s=stop  c=check  i=info"));
}

// Measures the input for about 1 second and prints a plain-language verdict.
void checkWiring() {
  const int N = 2000;
  uint32_t sum = 0, mn = 100000, mx = 0;
  for (int i = 0; i < N; i++) {
    uint32_t mv = analogReadMilliVolts(MIC_PIN);
    sum += mv;
    if (mv < mn) mn = mv;
    if (mv > mx) mx = mv;
    delayMicroseconds(400);
  }
  uint32_t mean = sum / N;
  uint32_t pp   = mx - mn;
  Serial.printf("# CHECK  mean %lu mV  min %lu mV  max %lu mV  peak-to-peak %lu mV\n",
                (unsigned long)mean, (unsigned long)mn, (unsigned long)mx, (unsigned long)pp);

  if (mean < 300) {
    Serial.println(F("# FAIL   input is near 0 V. Check MAX4466 VCC->3V3, GND->GND, OUT->R1->D34."));
  } else if (mean > 3000) {
    Serial.println(F("# FAIL   input is near 3.3 V. OUT may be on the wrong pin or touching VCC."));
  } else if (mean < 1350 || mean > 1950) {
    Serial.println(F("# WARN   bias should be about 1650 mV. Re-check wiring; module may be on 5 V."));
  } else {
    Serial.println(F("# OK     bias is correct (about half of 3.3 V). Wiring is good."));
  }

  if (mean < 300 || mean > 3000) {
    return;   // no microphone signal at all: gain advice would be misleading
  }
  if (mn < 150 || mx > 2450) {
    Serial.println(F("# GAIN   signal is clipping. Turn the gain screw a little; if it gets louder, turn it the other way."));
  } else if (pp < 15) {
    Serial.println(F("# GAIN   very small signal. Normal in silence; tap the chest piece and send c again."));
  } else {
    Serial.println(F("# GAIN   signal level is inside the ADC range."));
  }
}

void handleCommands() {
  while (Serial.available() > 0) {
    char ch = (char)Serial.read();
    switch (ch) {
      case 'r': case 'R': setMode(SM_RAW);  break;
      case 'v': case 'V': setMode(SM_VIEW); break;
      case 's': case 'S': setMode(SM_STOP); Serial.println(F("# stopped")); break;
      case 'i': case 'I': printInfo(); nextTick = micros(); break;
      case 'c': case 'C': checkWiring(); nextTick = micros(); break;
      default: break;  // ignore newline, carriage return and anything else
    }
  }
}

// ----------------------------- setup ----------------------------------------
void setup() {
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.setTxBufferSize(2048);   // so printing never stalls the sampler
  Serial.begin(BAUD);

  analogReadResolution(12);                     // values 0-4095
  analogSetPinAttenuation(MIC_PIN, ADC_11db);   // input range about 0.15-2.45 V (linear part)

  for (int i = 0; i < 32; i++) analogRead(MIC_PIN);   // warm up the ADC

  // Measure how long one read takes, then average as many reads as fit
  // in 60 % of each 250 us sample period (max 4). Works on any core version.
  uint32_t t0 = micros();
  for (int i = 0; i < 200; i++) analogRead(MIC_PIN);
  readTimeUs = (micros() - t0) / 200;
  if (readTimeUs == 0) readTimeUs = 1;
  uint32_t fit = (PERIOD_US * 6 / 10) / readTimeUs;
  if (fit < 1) fit = 1;
  if (fit > MAX_OVERSAMPLE) fit = MAX_OVERSAMPLE;
  oversample = (uint8_t)fit;

  delay(300);
  printInfo();
  checkWiring();
  Serial.println(F("# streaming raw samples (send v for plotter view, s to stop)"));
  setMode(SM_RAW);
}

// ----------------------------- loop -----------------------------------------
void loop() {
  handleCommands();
  if (mode == SM_STOP) return;

  uint32_t now  = micros();
  int32_t  late = (int32_t)(now - nextTick);
  if (late < 0) return;                       // not time yet
  if (late > (int32_t)(PERIOD_US * 20)) {     // fell far behind: restart the clock
    nextTick = now;
    resyncs++;
  }
  nextTick += PERIOD_US;

  uint16_t x = readSample();
  biasQ8 += (((int32_t)x << 8) - biasQ8) >> 8;   // slow average, follows the 1.65 V bias

  if (mode == SM_RAW) {
    sendNumber(x);
  } else {                                       // SM_VIEW: peak deviation per 40 ms
    int32_t dev = (int32_t)x - (biasQ8 >> 8);
    if (dev < 0) dev = -dev;
    if ((uint16_t)dev > viewPeak) viewPeak = (uint16_t)dev;
    if (++viewCount >= VIEW_DECIMATE) {
      sendNumber(viewPeak);
      viewCount = 0;
      viewPeak  = 0;
    }
  }
}
