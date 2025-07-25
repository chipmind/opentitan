// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/manuf/lib/flash_info_fields.h"

#include <stdint.h>

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/dif/dif_flash_ctrl.h"
#include "sw/device/lib/testing/flash_ctrl_testutils.h"
#include "sw/device/silicon_creator/lib/attestation.h"

#include "flash_ctrl_regs.h"  // Generated.
#include "otp_ctrl_regs.h"    // Generated.

/**
 * Partition 0, page 0 fields.
 */
const flash_info_field_t kFlashInfoFieldLotName = {
    .partition = 0,
    .bank = 0,
    .page = 0,
    .byte_offset = kFlashInfoFieldLotNameStartOffset,
};

const flash_info_field_t kFlashInfoFieldWaferNumber = {
    .partition = 0,
    .bank = 0,
    .page = 0,
    .byte_offset = kFlashInfoFieldWaferNumberStartOffset,
};

const flash_info_field_t kFlashInfoFieldWaferXCoord = {
    .partition = 0,
    .bank = 0,
    .page = 0,
    .byte_offset = kFlashInfoFieldWaferXCoordStartOffset,
};

const flash_info_field_t kFlashInfoFieldWaferYCoord = {
    .partition = 0,
    .bank = 0,
    .page = 0,
    .byte_offset = kFlashInfoFieldWaferYCoordStartOffset,
};

const flash_info_field_t kFlashInfoFieldProcessData = {
    .partition = 0,
    .bank = 0,
    .page = 0,
    .byte_offset = kFlashInfoFieldProcessDataStartOffset,
};

const flash_info_field_t kFlashInfoFieldAstCalibrationData = {
    .partition = 0,
    .bank = 0,
    .page = 0,
    .byte_offset = kFlashInfoFieldAstCalibrationDataStartOffset,
};

const flash_info_field_t kFlashInfoFieldCpDeviceId = {
    .partition = 0,
    .bank = 0,
    .page = 0,
    .byte_offset = kFlashInfoFieldCpDeviceIdStartOffset,
};

/**
 * Partition 0, page 1 fields.
 */
const flash_info_field_t kFlashInfoFieldCreatorSeed = {
    .partition = 0,
    .bank = 0,
    .page = 1,
    .byte_offset = 0,
};

/**
 * Partition 0, page 2 fields.
 */
const flash_info_field_t kFlashInfoFieldOwnerSeed = {
    .partition = 0,
    .bank = 0,
    .page = 2,
    .byte_offset = 0,
};

/**
 * Partition 0, page 3 fields.
 */
const flash_info_field_t kFlashInfoFieldWaferAuthSecret = {
    .partition = 0,
    .bank = 0,
    .page = 3,
    .byte_offset = 0,
};

/**
 * Partition 0, page 4 fields.
 */
const flash_info_field_t kFlashInfoFieldUdsAttestationKeySeed = {
    .partition = 0,
    .bank = 0,
    .page = 4,
    .byte_offset = kFlashInfoFieldUdsKeySeedIdx * kAttestationSeedBytes,
};

const flash_info_field_t kFlashInfoFieldCdi0AttestationKeySeed = {
    .partition = 0,
    .bank = 0,
    .page = 4,
    .byte_offset = kFlashInfoFieldCdi0KeySeedIdx * kAttestationSeedBytes,
};

const flash_info_field_t kFlashInfoFieldCdi1AttestationKeySeed = {
    .partition = 0,
    .bank = 0,
    .page = 4,
    .byte_offset = kFlashInfoFieldCdi1KeySeedIdx * kAttestationSeedBytes,
};

const flash_info_field_t kFlashInfoFieldTpmEkAttestationKeySeed = {
    .partition = 0,
    .bank = 0,
    .page = 4,
    .byte_offset = kFlashInfoFieldTpmEkKeySeedIdx * kAttestationSeedBytes,
};

const flash_info_field_t kFlashInfoFieldAttestationKeyGenVersion = {
    .partition = 0,
    .bank = 0,
    .page = 4,
    .byte_offset = FLASH_CTRL_PARAM_BYTES_PER_PAGE - sizeof(uint32_t),
};

status_t manuf_flash_info_field_read(dif_flash_ctrl_state_t *flash_state,
                                     flash_info_field_t field,
                                     uint32_t *data_out, size_t num_words) {
  dif_flash_ctrl_device_info_t device_info = dif_flash_ctrl_get_device_info();
  uint32_t byte_address =
      (field.page * device_info.bytes_per_page) + field.byte_offset;
  TRY(flash_ctrl_testutils_read(flash_state, byte_address, field.partition,
                                data_out, kDifFlashCtrlPartitionTypeInfo,
                                num_words,
                                /*delay=*/0));
  return OK_STATUS();
}

status_t manuf_flash_info_field_write(dif_flash_ctrl_state_t *flash_state,
                                      flash_info_field_t field,
                                      uint32_t *data_in, size_t num_words,
                                      bool erase_page_before_write) {
  dif_flash_ctrl_device_info_t device_info = dif_flash_ctrl_get_device_info();
  uint32_t byte_address =
      (field.page * device_info.bytes_per_page) + field.byte_offset;
  if (erase_page_before_write) {
    TRY(flash_ctrl_testutils_erase_and_write_page(
        flash_state, byte_address, field.partition, data_in,
        kDifFlashCtrlPartitionTypeInfo, num_words));
  } else {
    TRY(flash_ctrl_testutils_write(flash_state, byte_address, field.partition,
                                   data_in, kDifFlashCtrlPartitionTypeInfo,
                                   num_words));
  }
  return OK_STATUS();
}
