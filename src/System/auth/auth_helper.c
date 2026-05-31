#include <security/pam_appl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_PASSWORD_LEN 4096
#define ASTREA_PAM_SERVICE "system-auth"

static void secure_zero(void *ptr, size_t len) {
  volatile unsigned char *p = (volatile unsigned char *)ptr;
  while (len-- > 0)
    *p++ = 0;
}

static void free_responses(struct pam_response *responses, int count) {
  if (!responses)
    return;

  for (int i = 0; i < count; i++) {
    if (responses[i].resp) {
      secure_zero(responses[i].resp, strlen(responses[i].resp));
      free(responses[i].resp);
    }
  }
  free(responses);
}

static int conv_func(int num_msg, const struct pam_message **msg,
                     struct pam_response **resp, void *appdata_ptr) {
  if (num_msg <= 0 || !msg || !resp || !appdata_ptr)
    return PAM_CONV_ERR;

  const char *password = (const char *)appdata_ptr;
  struct pam_response *r = calloc((size_t)num_msg, sizeof(struct pam_response));
  if (!r)
    return PAM_BUF_ERR;

  for (int i = 0; i < num_msg; i++) {
    if (!msg[i]) {
      free_responses(r, i);
      return PAM_CONV_ERR;
    }

    switch (msg[i]->msg_style) {
    case PAM_PROMPT_ECHO_OFF:
      r[i].resp = strdup(password);
      if (!r[i].resp) {
        free_responses(r, i);
        return PAM_BUF_ERR;
      }
      break;
    case PAM_PROMPT_ECHO_ON:
      r[i].resp = strdup("");
      if (!r[i].resp) {
        free_responses(r, i);
        return PAM_BUF_ERR;
      }
      break;
    case PAM_ERROR_MSG:
    case PAM_TEXT_INFO:
      r[i].resp = NULL;
      break;
    default:
      free_responses(r, i);
      return PAM_CONV_ERR;
    }
  }

  *resp = r;
  return PAM_SUCCESS;
}

int main(int argc, char *argv[]) {
  if (argc != 2 || argv[1][0] == '\0')
    return 1;

  char *user = argv[1];
  char pass[MAX_PASSWORD_LEN] = {0};
  int result = 1;

  if (fgets(pass, sizeof(pass), stdin) == NULL)
    goto cleanup;

  pass[strcspn(pass, "\r\n")] = '\0';
  if (pass[0] == '\0')
    goto cleanup;

  struct pam_conv conv = {conv_func, pass};
  pam_handle_t *pamh = NULL;

  int ret = pam_start(ASTREA_PAM_SERVICE, user, &conv, &pamh);
  if (ret == PAM_SUCCESS) {
    ret = pam_authenticate(pamh, 0);
    if (ret == PAM_SUCCESS)
      ret = pam_acct_mgmt(pamh, 0);

    pam_end(pamh, ret);
    if (ret == PAM_SUCCESS)
      result = 0;
  }

cleanup:
  secure_zero(pass, sizeof(pass));
  return result;
}
