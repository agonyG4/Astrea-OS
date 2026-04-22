#include <security/pam_appl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int conv_func(int num_msg, const struct pam_message **msg,
                     struct pam_response **resp, void *appdata_ptr) {
  struct pam_response *r = calloc(num_msg, sizeof(struct pam_response));
  for (int i = 0; i < num_msg; i++)
    r[i].resp = strdup((char *)appdata_ptr);
  *resp = r;
  return PAM_SUCCESS;
}

int main(int argc, char *argv[]) {
  if (argc < 2)
    return 1;
  char *user = argv[1];
  char passbuf[512] = {0};
  char *pass = NULL;

  if (argc >= 3) {
    pass = argv[2];
  } else {
    if (fgets(passbuf, sizeof(passbuf), stdin) == NULL)
      return 1;
    passbuf[strcspn(passbuf, "\r\n")] = '\0';
    pass = passbuf;
  }

  if (pass[0] == '\0')
    return 1;

  struct pam_conv conv = {conv_func, pass};
  pam_handle_t *pamh = NULL;
  int ret;

  ret = pam_start("system-auth", user, &conv, &pamh);
  if (ret != PAM_SUCCESS) {
    fprintf(stderr, "pam_start falhou: %s\n", pam_strerror(pamh, ret));
    return 1;
  }

  ret = pam_authenticate(pamh, 0);
  fprintf(stderr, "pam_authenticate: %s\n", pam_strerror(pamh, ret));

  pam_end(pamh, ret);
  memset(passbuf, 0, sizeof(passbuf));
  return ret == PAM_SUCCESS ? 0 : 1;
}
