#include "my_helpers.h"
#include "gpio.h"

// GPIO pins
#define DRDY_PIN  4    // ADC data ready

#define SCLK_PIN  5    // SPI clock
#define CS_PIN    6    // active-low chip select
#define MISO_PIN  7    // input data line
#define MOSI_PIN  8    // output data line

void delay_short() {
    asm volatile ("nop; nop; nop; nop; nop; nop; nop; nop; nop; nop;"); // 10x nop
}

void gpio_init() {

    // SCLK
    gpio_pin_set_output(SCLK_PIN);  // Set direction to output
    gpio_pin_enable(SCLK_PIN);      // Enable the pin
    gpio_pin_clear(SCLK_PIN);       // Start low

    // CS
    gpio_pin_set_output(CS_PIN);
    gpio_pin_enable(CS_PIN);
    gpio_pin_set(CS_PIN);  // Deassert CS by default

    // MISO
    gpio_pin_enable(MISO_PIN); // Input

    // MOSI
    gpio_pin_enable(MOSI_PIN); // Output
    gpio_pin_set_output(MOSI_PIN);

    // DRDY from ADC
    gpio_pin_enable(DRDY_PIN);
}

uint8_t adc_ready() {
    return gpio_pin_read(DRDY_PIN);  // wait for DRDY to go high
}

uint16_t spi_read_16() {
    uint16_t data = 0;

    gpio_pin_clear(CS_PIN); // Assert CS (start transaction)
    delay_short();

    for (int i = 15; i >= 0; --i) {
        gpio_pin_set(SCLK_PIN);  // Rising edge
        delay_short();

        uint8_t bit = gpio_pin_read(MISO_PIN);
        data |= (bit << i);

        gpio_pin_clear(SCLK_PIN); // Falling edge
        delay_short();
    }

    gpio_pin_set(CS_PIN);  // Deassert CS (end transaction)

    return data;
}

void spi_send_16(uint16_t data) {
    gpio_pin_clear(SCLK_PIN); // Set clock to zero just in case
    gpio_pin_clear(CS_PIN); // Assert CS (start transaction)
    delay_short();

    for (int i = 15; i >= 0; --i) {
        // Prepare data
        if( (data >> i) & 1)
            gpio_pin_set(MOSI_PIN);
        else
            gpio_pin_clear(MOSI_PIN);

        gpio_pin_set(SCLK_PIN);  // Rising edge
        delay_short();

        gpio_pin_clear(SCLK_PIN); // Falling edge
        delay_short();
    }

    gpio_pin_set(CS_PIN);  // Deassert CS (end transaction)
}
