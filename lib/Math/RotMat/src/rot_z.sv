module rot_z #(
    parameter unsigned DATA_WIDTH = 24,
    parameter unsigned FRAC_BITS = 13,
    parameter unsigned TRIG_LUT_ADDR_WIDTH = 12
) (
    input logic clk,
    input logic [TRIG_LUT_ADDR_WIDTH-1:0] angle,
    output logic signed [DATA_WIDTH-1:0] rot_z_mat[4][4]
);

    logic signed [DATA_WIDTH-1:0] sine;
    logic signed [DATA_WIDTH-1:0] cosine;

    sin_cos_lu #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(TRIG_LUT_ADDR_WIDTH)
    ) sin_cos_lu_inst (
        .clk(clk),
        .angle(angle),
        .sine(sine),
        .cosine(cosine)
    );

    always_comb begin
        rot_z_mat[0][0] = cosine;
        rot_z_mat[0][1] = -sine;
        rot_z_mat[0][2] = 0;
        rot_z_mat[0][3] = 0;
        rot_z_mat[1][0] = sine;
        rot_z_mat[1][1] = cosine;
        rot_z_mat[1][2] = 0;
        rot_z_mat[1][3] = 0;
        rot_z_mat[2][0] = 0;
        rot_z_mat[2][1] = 0;
        rot_z_mat[2][2] = 1 << FRAC_BITS;
        rot_z_mat[2][3] = 0;
        rot_z_mat[3][0] = 0;
        rot_z_mat[3][1] = 0;
        rot_z_mat[3][2] = 0;
        rot_z_mat[3][3] = 1 << FRAC_BITS;
    end

endmodule
