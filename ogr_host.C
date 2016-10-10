// tty interface follows StackOverflow.com
// http://stackoverflow.com/questions/6947413/how-to-open-read-and-write-from-serial-port-in-c?rq=1
//
// Adaptation for interaction with iCEstick HX40 1K FPGA to support the 2-byte-adder example
// by Steffen Moeller, Niendorf/Ostsee 2016

#include <errno.h>
#include <fcntl.h> 
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

int
set_interface_attribs (int USB, int speed, int parity)
{
   struct termios tty;
   memset (&tty, 0, sizeof tty);
   if (tcgetattr (USB, &tty) != 0)
   {
      fprintf(stderr,"error %d from tcgetattr", errno);
      return(-1);
   }

   cfsetospeed (&tty, speed);
   cfsetispeed (&tty, speed);

   tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8;     // 8-bit chars
   // disable IGNBRK for mismatched speed tests; otherwise receive break
   // as \000 chars
   tty.c_iflag &= ~IGNBRK;         // disable break processing
   tty.c_lflag = 0;                // no signaling chars, no echo,
               // no canonical processing
   tty.c_oflag = 0;                // no remapping, no delays
   tty.c_cc[VMIN]  = 0;            // read doesn't block
   tty.c_cc[VTIME] = 5;            // 0.5 seconds read timeout

   tty.c_iflag &= ~(IXON | IXOFF | IXANY); // shut off xon/xoff ctrl

   tty.c_cflag |= (CLOCAL | CREAD);// ignore modem controls,
               // enable reading
   tty.c_cflag &= ~(PARENB | PARODD);      // shut off parity
   tty.c_cflag |= parity;
   tty.c_cflag &= ~CSTOPB;
   tty.c_cflag &= ~CRTSCTS;

   if (tcsetattr (USB, TCSANOW, &tty) != 0)
   {
      fprintf(stderr,"error %d from tcsetattr", errno);
      return(-1);
   }
   return(0);
}

void
set_blocking (int USB, int should_block)
{
   struct termios tty;
   memset (&tty, 0, sizeof tty);
   if (tcgetattr (USB, &tty) != 0)
   {
      fprintf(stderr,"error %d from tggetattr", errno);
      return;
   }

   tty.c_cc[VMIN]  = should_block ? 1 : 0;
   tty.c_cc[VTIME] = 5;            // 0.5 seconds read timeout

   if (tcsetattr (USB, TCSANOW, &tty) != 0)
      fprintf(stderr,"error %d setting term attributes", errno);
}

const unsigned char num_fixed_positions=3;
struct __attribute__((packed)) input {
   unsigned short maximum;
   unsigned char  npos;
   unsigned char  positions[num_fixed_positions];
} input;

struct __attribute__((packed)) output {
   unsigned short maximum;
   unsigned short found;
   unsigned char  npos;
   unsigned char  positions[num_fixed_positions];
} output;

unsigned char* const write_n_and_read_m (const int device,
             unsigned char const * const writeme, const int n,
             unsigned char       * const readtome,const int m) {

   int n_written = 0,
       spot_w = 0;

   int n_read = 0,
       spot_r = 0;



   // Write:

   while( (n>0 && n>spot_w) || (0==n && strlen((char *)writeme)>spot_w)) {
      n_written = write( device, writeme+spot_w, 1);
      spot_w += n_written;
      fprintf(stderr,"Written: %d, n=%d, n_written=%d, spot_w=%d\n", *(writeme+spot_w-n_written), n, n_written, spot_w);
      usleep(350);
   }

   //fprintf(stderr,"Now reading: n=%d, n_written=%d, spot_w=%d\n", n, n_written, spot_w);
   //fprintf(stderr,"             m=%d, m_written=%d, spot_r=%d\n", n, n_read,    spot_r);

   // Read:

   do {
       unsigned char buf = '\0';
       n_read = read( device, &buf, 1 );
       readtome[spot_r]=buf;
       spot_r += n_read;
       fprintf(stderr,"Read character # %d ! m=%d, n_read=%d, spot_r=%d\n",buf,m,n_read,spot_r);
       
       if (n_read < 0) {
         fprintf(stderr,"Error %d reading: %s\n", errno, strerror(errno));
       }
       else if (n_read == 0) {
         fprintf(stderr,"Read nothing!\n");
       }
   } while ( (m>0 && spot_r<m) || (0==m && writeme[spot_w] != 0));

   if (0==m) readtome[spot_r]=0;
   return(readtome);
}


int
main(int argc, char *argv[]) {

   const char *portname = NULL;

   if (argc<3+num_fixed_positions) {
      fprintf(stderr,"Usage: %s <device> <maxlength> <1st",argv[0]);
      if (num_fixed_positions>2) fprintf(stderr," ... <%dth",num_fixed_positions);
      else if (2==num_fixed_positions) fprintf(stderr," <2nd");
      fprintf(stderr," fixed position>\n");
      fprintf(stderr,"argc=%d\n",argc);
      fprintf(stderr,"sizeof(struct input):  %d\n",sizeof(struct input));
      fprintf(stderr,"sizeof(struct output): %d\n",sizeof(struct output));

      exit(1);
   } 

   fprintf(stderr,"ogr_host\n");

   portname = strdup(argv[1]);

   int USB = open (portname, O_RDWR | O_NOCTTY | O_SYNC);
   if (USB < 0)
   {
      fprintf(stderr,"error %d opening %s: %s\n", errno, portname, strerror (errno));
      return(errno);
   }

   //set_interface_attribs (USB, B115200, 0);  // set speed to 115,200 bps, 8n1 (no parity)
   set_interface_attribs (USB, B9600, 0);  // set speed to 115,200 bps, 8n1 (no parity)

   {
      char buf [10000];
      set_blocking (USB, 0);   // disable reads blocked when no input ready
      int n;
      do {
         n = read (USB, buf, sizeof buf);
      } while (n > 0);
   }


   set_blocking (USB, 1);                // set blocking

   input.maximum=(unsigned short) atoi(argv[2]);
   input.npos=num_fixed_positions;
   for(unsigned char i=0; i<num_fixed_positions; i++) {
      input.positions[i]=(unsigned char) atoi(argv[3+i]);
      fprintf(stderr,"I: interpreted argument '%d' from command line as position\n",input.positions[i]);
   }

   fprintf(stderr,"I: sending to device '%s':\n", argv[1]);
   fprintf(stderr,"I: maximum: %d\n", input.maximum);
   fprintf(stderr,"I: npos: %d\n", input.npos);
   for(unsigned char j=0; j<num_fixed_positions; j++) {
      fprintf(stderr,"I:  pos %d: %d\n", output.positions[j]);
   }

   write_n_and_read_m(USB,(unsigned char *) &input,  sizeof (struct input),
                          (unsigned char *) &output, sizeof (struct output));

   fprintf(stderr,"I: received from device '%s':\n", argv[1]);
   fprintf(stderr,"I:  maximum: %d\n", output.maximum);
   fprintf(stderr,"I:    found: %d\n", output.found);
   fprintf(stderr,"I:     npos: %d\n", output.npos);
   for(unsigned char k=0; k<num_fixed_positions; k++) {
      fprintf(stderr,"I:  pos %d: %d\n", *(output.positions+k));
   }

   close(USB);

   return(0);
}
