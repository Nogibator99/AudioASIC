// Copyright (c) 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0/
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>

#include "uart.h"
#include "print.h"
#include "timer.h"
#include "gpio.h"
#include "util.h"
#include "my_helpers.h"

// 0 - LPF cutoff, {0-1024}
// 1 - HPF cutoff, 2048 - {0-1024}
int encoders [2] = {500, 2048-20};

void update_encoders() {

    // read encoder values from uart
    uint8_t cnt = 2;
    while (uart_read_ready()) {

        // Arduino sends: [0xFF][id][lo][hi]
        if (uart_read() == 0xFF) {

            // read id
            while (!uart_read_ready());
            uint8_t id = uart_read();

            // read low byte
            while (!uart_read_ready());
            uint8_t lo = uart_read();

            // read high byte
            while (!uart_read_ready());
            uint8_t hi = uart_read();

            // combine low + high and store in the array
            uint16_t val = ((uint16_t)hi << 8) | lo;
            encoders[id] = val;

            // don't get stuck if uart still has data
            if(--cnt == 0)
                return;
        }
    }

    // write encoder values to effects
    *reg32(USER_AU_LPF_CASCADE_BASE_ADDR, 0x4) = encoders[0];
    *reg32(USER_AU_HPF_CASCADE_BASE_ADDR, 0x4) = encoders[1]; // REMEMBER ABOUT 2048!!!
}

int main() {
    uart_init(); // setup the uart peripheral

    printf("Hello World!\n");

    // wait until uart has finished sending
    uart_write_flush();

    // Configure GPIO
    gpio_init();

    // main infinite loop
    while(1) {

        // if ADC has NOT asserted DRDY
        while(adc_ready() == 0) {

            // update encoder values from uart
            update_encoders();
        }

        // ADC is ready - process new sample

        // push data from ADC to audio interface
        *reg32(USER_AU_AUDIO_INTERFACE_BASE_ADDR, 0x0) = spi_read_16();

        // wait for processing
        delay_short();
        delay_short();
        delay_short();

        // send processed data to DAC
        spi_send_16(*reg32(USER_AU_AUDIO_INTERFACE_BASE_ADDR, 0x4));
    }

    // ----- DEBUG ----- 
    *reg32(USER_AU_LPF_CASCADE_BASE_ADDR, 0x4) = encoders[0];
    *reg32(USER_AU_HPF_CASCADE_BASE_ADDR, 0x4) = encoders[1]; // REMEMBER ABOUT 2048!!!

    // -----------------

    uart_write_flush();

    // using the timer
    printf("Tick\n");
    //sleep_ms(10);
    printf("Tock\n");
    uart_write_flush();
    return 1;
}

