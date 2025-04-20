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

int main() {
    uart_init(); // setup the uart peripheral

    // simple printf support (only prints text and hex numbers)
    printf("Hello World!\n");
    // wait until uart has finished sending
    uart_write_flush();

    // Write some filters coefficients
    int LPF_decay = 512;    // 0 - 1024
    int HPF_decay = 100;    // 0 - 1024

    *reg32(USER_AU_FILTERS_CASCADE_BASE_ADDR, 0x4) = LPF_decay;
    *reg32(USER_AU_FILTERS_CASCADE_BASE_ADDR, 0x8) = 2048 - HPF_decay;

    // Configure GPIO
    gpio_init();

    // while(1)
    // for(int i = 0; i < 1000; i++) {

    //     // wait when ADC asserts DRDY
    //     wait_for_adc_ready();

    //     // push data from ADC to audio interface
    //     *reg32(USER_AU_AUDIO_INTERFACE_BASE_ADDR, 0x0) = spi_read_16();

    //     // wait for processing
    //     delay_short();
    //     delay_short();
    //     delay_short();

    //     // send processed data to DAC
    //     spi_send_16(*reg32(USER_AU_AUDIO_INTERFACE_BASE_ADDR, 0x4));
    // }

    uart_write_flush();

    // using the timer
    printf("Tick\n");
    //sleep_ms(10);
    printf("Tock\n");
    uart_write_flush();
    return 1;
}

