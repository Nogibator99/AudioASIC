#pragma once

#include <stdint.h>

// GPIO pins
#define DRDY_PIN  4    // ADC data ready

#define SCLK_PIN  5    // SPI clock
#define CS_PIN    6    // active-low chip select
#define MISO_PIN  7    // input data line
#define MOSI_PIN  8    // output data line

void delay_short();
void gpio_init();
void wait_for_adc_ready();
uint16_t spi_read_16();
void spi_send_16(uint16_t data);